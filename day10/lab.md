[⬅ Back to labs](../SPRINT.md)

# Day 10 Lab — EC2 Pulls from ECR, Then Kubernetes with kind

**The task (sprint plan):**
**Morning (~1 h):** create an EC2 with an instance profile (SSM + ECR read), then pull your image and run it by hand.
**Afternoon (~3 h):** install `kubectl` and kind, create a local cluster and load your image with `kind load docker-image`. Deploy it as a Deployment with 3 replicas behind a Service. Delete a pod and watch it come back, scale to 5, then roll out a new tag and roll it back. In the README, write 5 lines on what Kubernetes did that `docker run` on EC2 couldn't.

**Date:** 2026-11-18/19 · **Where:** WSL Ubuntu 24.04 + AWS CLI (profile `sprint2`, `us-east-1`) + Docker Desktop 29.6.1
**Cost:** morning ≈ $0.02 (`t3.micro` + public IPv4 ≈ $0.016/hour, terminated the same day); afternoon $0 (kind runs on the laptop)
**Result:** the ECR image `capstone:ec0a5a6f…` answered `/health` on EC2; on kind the Deployment self-healed, scaled to 5, rolled out `v2` and rolled back. 5 lines in [README.md](README.md).

> The 12-digit AWS account ID is written as `<id>`.

| Requirement | Result |
|---|---|
| EC2 with an instance profile (SSM + ECR read) | ✅ role + profile `ec2-capstone-pull`; `assumed-role/ec2-capstone-pull/i-0…` from inside |
| Pull the image and run it by hand | ✅ `docker pull …/capstone:ec0a5a6f…` → `docker run` → `/health` = `{"status":"ok"}` |
| `kubectl` + kind, local cluster, `kind load` | ✅ kubectl v1.37.2, kind v0.33.0, node v1.37.0 |
| Deployment with 3 replicas behind a Service | ✅ `3/3`, Service `ClusterIP` port 80 → 8000 |
| Delete a pod → it comes back | ✅ new pod in seconds (**Self-check 2**) |
| Scale to 5 | ✅ `5/5` |
| Roll out a new tag, roll it back | ✅ `v2` → `rollout undo` |
| 5 lines in the README | ✅ [README.md](README.md) |

### Self-check 2
| Item | Status |
|---|---|
| PR checks are green and enforced | ✅ Day 8 |
| An image with SHA tags is in ECR, pushed through OIDC | ✅ Day 9 |
| The app answers `/health` on EC2 | ✅ Morning lab |
| On kind, the app comes back after you delete a pod | ✅ Afternoon lab |

---

# Morning — EC2 pulls the image from ECR

```text
role ec2-capstone-pull (trust: ec2.amazonaws.com; SSM + pull capstone)
   └─ instance profile ec2-capstone-pull ──attached──► EC2 t3.micro (AL2023, IMDSv2, SG: 0 inbound)
          Session Manager → swap → install Docker → ECR login → docker pull → docker run → curl /health
```

## Part 1 — Role + instance profile (IAM only, free)

### 1.0 Terminal setup
```bash
export AWS_PROFILE=sprint2
export AWS_REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
```

### 1.1 Trust policy — the EC2 service may assume the role
```bash
cat > /tmp/ec2-trust.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow", "Principal": { "Service": "ec2.amazonaws.com" }, "Action": "sts:AssumeRole" }
  ]
}
EOF
aws iam create-role --role-name ec2-capstone-pull \
  --assume-role-policy-document file:///tmp/ec2-trust.json \
  --description "Day 10 EC2: SSM + pull capstone from ECR" \
  --tags Key=Project,Value=devops-sprint --query 'Role.Arn' --output text
```
| Part | Meaning |
|---|---|
| `"Principal": { "Service": "ec2.amazonaws.com" }` | Who: the EC2 service, for an instance (Day 9 was `Federated`: GitHub) |
| `"Action": "sts:AssumeRole"` | A plain assume-role, no web token |

### 1.2 Session Manager (AWS managed policy)
```bash
aws iam attach-role-policy --role-name ec2-capstone-pull \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
```
| Part | Meaning |
|---|---|
| `attach-role-policy` | Attach a **managed** policy (Day 9 used an inline one) |
| `arn:aws:iam::aws:policy/…` | Account field `aws` = written and maintained by AWS |

### 1.3 Pull from `capstone` only (inline)
```bash
cat > /tmp/ec2-pull.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    { "Sid": "EcrLogin", "Effect": "Allow", "Action": "ecr:GetAuthorizationToken", "Resource": "*" },
    { "Sid": "PullCapstoneOnly", "Effect": "Allow",
      "Action": ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"],
      "Resource": "arn:aws:ecr:us-east-1:${ACCOUNT_ID}:repository/capstone" }
  ]
}
EOF
aws iam put-role-policy --role-name ec2-capstone-pull \
  --policy-name ecr-pull-capstone --policy-document file:///tmp/ec2-pull.json
```
| Action | Why `docker pull` needs it |
|---|---|
| `GetAuthorizationToken` (`*`) | Docker login (registry-wide) |
| `BatchGetImage` | Read the manifest |
| `GetDownloadUrlForLayer` | Download each layer |
| `BatchCheckLayerAvailability` | Check layers |

Least privilege: one repo and **no push** (the managed `AmazonEC2ContainerRegistryReadOnly` reads every repo).

### 1.4 Instance profile
```bash
aws iam create-instance-profile --instance-profile-name ec2-capstone-pull --tags Key=Project,Value=devops-sprint
aws iam add-role-to-instance-profile --instance-profile-name ec2-capstone-pull --role-name ec2-capstone-pull
aws iam get-instance-profile --instance-profile-name ec2-capstone-pull --query 'InstanceProfile.Roles[].RoleName' --output text
rm /tmp/ec2-trust.json /tmp/ec2-pull.json
```
| Part | Meaning |
|---|---|
| Instance profile | The holder EC2 attaches; it carries exactly one role. The console creates it automatically, the CLI doesn't. |

**Part 1 = IAM only** (role, trust, 2 permissions, profile) — no server yet, nothing billable.

## Part 2 — Launch the instance

### 2.1 AMI and default VPC
```bash
AMI_ID=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 --query Parameter.Value --output text)
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
```
| Part | Meaning |
|---|---|
| `/aws/service/ami-amazon-linux-latest/…` | AWS's public parameter with the newest Amazon Linux 2023 AMI |
| `is-default=true` | The default VPC: public subnets + IGW + public IPs |

### 2.2 Security group with no inbound rules
```bash
SG_ID=$(aws ec2 create-security-group --group-name day10-no-inbound \
  --description "Day 10: no inbound; SSM and ECR use outbound only" --vpc-id "$VPC_ID" \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Project,Value=devops-sprint}]' \
  --query GroupId --output text)
```
Result: `day10-no-inbound 0 1` — 0 inbound, 1 outbound. Session Manager and `docker pull` start **from inside**; security groups are stateful, so replies come back.

### 2.3 Launch
```bash
INSTANCE_ID=$(aws ec2 run-instances --image-id "$AMI_ID" --instance-type t3.micro \
  --iam-instance-profile Name=ec2-capstone-pull --security-group-ids "$SG_ID" \
  --metadata-options HttpTokens=required,HttpEndpoint=enabled \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=day10-capstone},{Key=Project,Value=devops-sprint}]' 'ResourceType=volume,Tags=[{Key=Project,Value=devops-sprint}]' \
  --query 'Instances[0].InstanceId' --output text)
printf 'INSTANCE_ID=%s\nSG_ID=%s\n' "$INSTANCE_ID" "$SG_ID" > ~/day10-lab.env
```
| Part | Meaning |
|---|---|
| `--iam-instance-profile Name=ec2-capstone-pull` | Attach the profile from Part 1 |
| `HttpTokens=required` | **IMDSv2 only** — metadata (and the role's keys) need a session token |
| No `--subnet-id` | A default public subnet with a public IP → reach SSM and ECR without a NAT gateway |
| `~/day10-lab.env` | Save IDs for cleanup from any terminal |

### 2.4 Ready + registered with SSM
```bash
aws ec2 wait instance-status-ok --instance-ids "$INSTANCE_ID" && echo "instance OK"
aws ssm describe-instance-information --filters Key=InstanceIds,Values="$INSTANCE_ID" \
  --query 'InstanceInformationList[0].[InstanceId,PingStatus,PlatformName]' --output text
```
Result: `running t3.micro <public-ip> …instance-profile/ec2-capstone-pull required` and `i-0… Online Amazon Linux`.

## Part 3 — Connect and prepare (inside the instance)

### 3.1 Connect
```bash
session-manager-plugin --version
aws ssm start-session --target "$INSTANCE_ID"
```
Prompt `sh-5.2$` = on the instance as `ssm-user`.

### 3.2 Who is this server?
```bash
aws sts get-caller-identity --query Arn --output text
```
Result: `arn:aws:sts::<id>:assumed-role/ec2-capstone-pull/i-0e08a75c63862aaef` — keys from **IMDS**, none stored.

### 3.3 Swap (1 GB)
```bash
sudo dd if=/dev/zero of=/swapfile bs=1M count=1024 status=none
sudo chmod 600 /swapfile
sudo mkswap /swapfile >/dev/null
sudo swapon /swapfile
free -h
```
Result: `Mem: 913Mi total, 634Mi available` · `Swap: 1.0Gi`. `buff/cache` is reclaimable — `available` is the number to watch.

### 3.4 Docker
```bash
sudo dnf install -y -q docker
sudo systemctl enable --now docker
sudo systemctl is-active docker
sudo docker version --format 'client {{.Client.Version}} / server {{.Server.Version}}'
```
Result: `active` · `client 25.0.14 / server 25.0.18` (plus `containerd`, `runc`).

## Part 4 — Pull from ECR and run (inside the instance)
```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REG="$ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com"
aws ecr get-login-password --region us-east-1 | sudo docker login --username AWS --password-stdin "$REG"
IMAGE="$REG/capstone:ec0a5a6f7eafc1cc28e72ef6fa93a4f4db41b523"
sudo docker pull "$IMAGE"
sudo docker run -d --name capstone --restart unless-stopped -p 8000:8000 "$IMAGE"
sleep 15
sudo docker ps
curl -s localhost:8000/health; echo
curl -s localhost:8000/items; echo
sudo docker inspect --format '{{.Config.User}} {{.State.Health.Status}}' capstone
```
| Part | Meaning |
|---|---|
| `get-login-password \| docker login --password-stdin` | 12-hour Docker password via the role; never typed |
| `capstone:ec0a5a6f…` | The exact image the Day 9 pipeline pushed |
| `--restart unless-stopped` | Docker restarts it on crash/reboot — single-server "self-healing" |
| `-p 8000:8000` | Reachable only from inside (no inbound rule) |
| **Result** | `Login Succeeded` · `Up … (healthy)` · `{"status":"ok"}` · the 2 items · `app healthy` |

## Part 5 — Clean up
```bash
sudo docker logout "$REG"
exit
```
Then in WSL:
```bash
source ~/day10-lab.env
aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --query 'TerminatingInstances[0].CurrentState.Name' --output text
aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID" && echo "instance terminated"
aws ec2 delete-security-group --group-id "$SG_ID" && echo "security group deleted"
aws ec2 describe-instances --filters Name=tag:Project,Values=devops-sprint Name=instance-state-name,Values=pending,running,stopping,stopped --query 'length(Reservations)' --output text
aws ec2 describe-volumes --filters Name=tag:Project,Values=devops-sprint --query 'length(Volumes)' --output text
rm ~/day10-lab.env
```
| Part | Meaning |
|---|---|
| Terminate ≠ stop | Stop keeps the disk (still billed); terminate deletes it |
| SG after the wait | A security group can't be deleted while an instance uses it |
| Kept (free) | Role + profile `ec2-capstone-pull`; ECR `capstone` (≈ $0.003/month) |

---

# Afternoon — Kubernetes with kind

```text
Windows → Docker Desktop
           └── container <cluster>-control-plane            ← the node (visible in Docker Desktop → Containers)
                 ├── control plane: apiserver, etcd, scheduler, controller-manager (static pods)
                 ├── kubelet + containerd
                 └── pods capstone-<rs-hash>-<id>            ← NOT visible in Docker Desktop
WSL: kind + kubectl (clients) · ~/.kube/config (context kind-<cluster>)
```

## Part 1 — Install `kubectl` and kind (checksums verified)
```bash
docker version --format '{{.Server.Version}}'
KUBECTL_VER=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/$KUBECTL_VER/bin/linux/amd64/kubectl"
curl -fsSLo /tmp/kubectl.sha256 "https://dl.k8s.io/release/$KUBECTL_VER/bin/linux/amd64/kubectl.sha256"
echo "$(cat /tmp/kubectl.sha256)  /tmp/kubectl" | sha256sum --check
sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
rm /tmp/kubectl /tmp/kubectl.sha256
kubectl version --client
KIND_VER=$(gh release view --repo kubernetes-sigs/kind --json tagName --jq .tagName)
curl -fsSLo /tmp/kind "https://github.com/kubernetes-sigs/kind/releases/download/$KIND_VER/kind-linux-amd64"
curl -fsSLo /tmp/kind.sha256 "https://github.com/kubernetes-sigs/kind/releases/download/$KIND_VER/kind-linux-amd64.sha256sum"
echo "$(cut -d' ' -f1 /tmp/kind.sha256)  /tmp/kind" | sha256sum --check
sudo install -m 0755 /tmp/kind /usr/local/bin/kind
rm /tmp/kind /tmp/kind.sha256
kind version
```
| Part | Meaning |
|---|---|
| `dl.k8s.io/release/stable.txt` | Latest stable Kubernetes version |
| `sha256sum --check` | Must print `OK` — the download wasn't corrupted or tampered with |
| `install -m 0755 … /usr/local/bin/` | Put the binary on the `PATH`, executable |
| `gh release view --repo kubernetes-sigs/kind` | kind's latest release tag |
| **Result** | Docker `29.6.1` · `Client Version: v1.37.2` · `kind v0.33.0` |

## Part 2 — Create the cluster
```bash
kind create cluster --name capstone
kubectl cluster-info --context kind-capstone
kubectl get nodes -o wide
docker ps --filter name=capstone --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'
kubectl get pods -n kube-system
```
| Part | Meaning |
|---|---|
| `kind create cluster --name capstone` | Docker starts the node container `capstone-control-plane` (`kindest/node:v1.37.0`); Kubernetes boots inside; context `kind-capstone` |
| `cluster-info` | The API server at `https://127.0.0.1:<port>` |
| `get nodes` | `capstone-control-plane Ready control-plane v1.37.0` |
| `docker ps` | The node is a container |

**System pods** (`kube-system`, built in):
| Pod | Kind | Job |
|---|---|---|
| `kube-apiserver-…`, `etcd-…`, `kube-scheduler-…`, `kube-controller-manager-…` | Static pods | The control plane |
| `kube-proxy-…` | DaemonSet | Service networking on each node |
| `kindnet-…` | DaemonSet | kind's pod network (CNI) |
| `coredns-…` ×2 | Deployment | DNS: `capstone` → the Service IP |

> **Docker Desktop's Kubernetes page stays empty** — it shows only clusters Docker Desktop itself creates ("Create cluster", context `docker-desktop`). Our cluster appears under **Containers**. Don't create a second cluster there.

## Part 3 — Images on the node
```bash
cd ~/Devops-Sprint-Wisam
git switch labs && git pull
git switch -c lab/day10-k8s
mkdir -p day10/k8s
docker build -q -t capstone:v1 day08
docker tag capstone:v1 capstone:v2
kind load docker-image capstone:v1 capstone:v2 --name capstone
docker exec capstone-control-plane crictl images | grep capstone
```
| Part | Meaning |
|---|---|
| `docker tag capstone:v1 capstone:v2` | Same image, second name — enough for Kubernetes to see a **new template** and roll out |
| `kind load docker-image …` | Copy into the node's own containerd; a new node starts empty |
| `crictl images` | The node's image list (`docker.io/library/capstone v1/v2`) |

After loading, the images **wait** — nothing runs until a Deployment asks for them. On `apply`, the kubelet finds them locally (`IfNotPresent`) and containerd starts containers from them. They stay until the cluster is deleted (or image garbage collection).

## Part 4 — Deployment + Service
Files: [k8s/deployment.yaml](k8s/deployment.yaml), [k8s/service.yaml](k8s/service.yaml).

| Deployment line | Meaning |
|---|---|
| `replicas: 3` | Desired: 3 pods |
| `selector.matchLabels` / `template.metadata.labels` = `app: capstone` | Must match — how the Deployment owns its pods |
| `name: api`, `image: capstone:v1` | The container (`api` is used by `set image`) |
| `imagePullPolicy: IfNotPresent` | Use the node's copy |
| `readinessProbe` `GET /health :8000` every 5 s | Traffic only when ready (Kubernetes ignores the Dockerfile `HEALTHCHECK`) |

| Service line | Meaning |
|---|---|
| `selector: app: capstone` | Send to ready pods with this label |
| `port: 80` → `targetPort: 8000` | Service port → pod port |
| No `type:` | ClusterIP — internal only |

```bash
kubectl apply -f day10/k8s/
kubectl rollout status deployment/capstone --timeout=120s
kubectl get deploy,rs,pods,svc -l app=capstone -o wide
```
**Result:**
```text
deployment.apps/capstone   3/3   3   3   …   api   capstone:v1   app=capstone
replicaset.apps/capstone-6f59564f6f   3   3   3   …   app=capstone,pod-template-hash=6f59564f6f
pod/capstone-6f59564f6f-j4lnt   1/1   Running   0   10.244.0.5   …-control-plane
pod/capstone-6f59564f6f-vsn2c   1/1   Running   0   10.244.0.6
pod/capstone-6f59564f6f-zbqvw   1/1   Running   0   10.244.0.7
service/capstone   ClusterIP   10.96.184.114   80/TCP   app=capstone
```
| Name piece | Meaning |
|---|---|
| `6f59564f6f` | `pod-template-hash` — new template → new hash → new ReplicaSet |
| Pod IPs `10.244.0.x` | Change when pods are replaced |
| Service IP `10.96.184.114` | Stable |

Where the pods are: inside the node container — `docker exec <cluster>-control-plane crictl ps --name api` lists their containers.

```bash
kubectl port-forward svc/capstone 8090:80 >/dev/null 2>&1 &
PF=$!
sleep 2
curl -s localhost:8090/health; echo
curl -s localhost:8090/items; echo
kill $PF
```
| Part | Meaning |
|---|---|
| `port-forward svc/capstone 8090:80` | `localhost:8090` → Service → a pod's 8000 (ClusterIP isn't reachable from WSL) |
| `&` · `PF=$!` · `kill $PF` | Background, save the PID, close the tunnel |
| **Result** | `{"status":"ok"}` and the 2 items |

## Part 5 — Self-healing and scaling
Second terminal: `kubectl get pods -l app=capstone -w`
```bash
POD=$(kubectl get pods -l app=capstone -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod "$POD" --wait=false
kubectl get pods -l app=capstone
kubectl scale deployment capstone --replicas=5
kubectl rollout status deployment/capstone --timeout=60s
kubectl get deploy capstone
```
| Observation | Why |
|---|---|
| Old pod `Terminating`, new pod `Pending → ContainerCreating → 0/1 Running → 1/1 Running` | ReplicaSet: desired 3, current 2 → create 1. `0/1` until the readiness probe passes. |
| New pod has a new name and IP | Pods are replaceable; the Service is the stable address |
| `READY 5/5` after `scale` | Desired state changed; the Service includes new pods by label |
| `scale` is imperative | The YAML still says 3 — a later `kubectl apply` resets it |

## Part 6 — Roll out a new tag, roll it back
```bash
kubectl set image deployment/capstone api=capstone:v2
kubectl annotate deployment/capstone kubernetes.io/change-cause="roll out capstone:v2" --overwrite
kubectl rollout status deployment/capstone --timeout=120s
kubectl get rs -l app=capstone -o wide
kubectl rollout history deployment/capstone
kubectl rollout undo deployment/capstone
kubectl rollout status deployment/capstone --timeout=120s
kubectl get deploy capstone -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
kubectl rollout history deployment/capstone
```
| Concept | Meaning |
|---|---|
| **Rollout** | Replacing a Deployment's pods with a new version of the **pod template** (image, env, probes…). `replicas` changes are scaling, not rollouts. |
| `set image … api=capstone:v2` | New template → new ReplicaSet; RollingUpdate (25 % surge / 25 % unavailable by default) → no downtime |
| Two ReplicaSets | Old one kept at 0 for instant rollback |
| `rollout history` | Revisions; `change-cause` from the annotation |
| `rollout undo` | Roll back to the **previous** revision (one step back — not necessarily v1); old ReplicaSet scales up, no rebuild |
| History after undo | The old revision reappears with a new number |

**The `rollout undo` warning:** *"previously managed with 'kubectl apply' … will not update the last-applied-configuration annotation"* — `undo` is imperative, so the file, the stored last-applied copy and the live object can disagree; the next `kubectl apply` makes the cluster match the **file**. Teams undo first in an emergency, then fix the YAML in Git (declarative rollback).

## Part 7 — Clean up
```bash
kind delete cluster --name capstone
kind get clusters
```
Kept: `kubectl`, kind, the images in Docker Desktop, the YAML files.

---

## Troubleshooting (hit during this lab)

| Symptom | Cause | Fix |
|---|---|---|
| `ERROR: no nodes found for cluster "capstone-test"` | Name typo — the cluster was `capstone-tset` | Copy the name from `kind get clusters`; keep names short (`lab`) |
| `apply` printed only `service/capstone created`; `deployments.apps "capstone" not found` | `deployment.yaml` empty/missing (heredoc not run) | `wc -l day10/k8s/*.yaml`; re-run the heredoc; `apply` again (declarative — safe to repeat) |
| `Command 'then' not found` | "then" in the notes meant "next" | Run each command on its own line |
| 3 ReplicaSets after several rollouts | One per pod-template version | `kubectl get rs -o wide` shows each one's image |
| Docker Desktop's Kubernetes page is empty | It only lists its own clusters | Look under **Containers** |
| `ErrImagePull` / `ImagePullBackOff` | Image not loaded on the node | `kind load docker-image … --name <cluster>` |
| `docker: not found` in WSL / kind can't list clusters | Docker Desktop stopped | Start Docker Desktop |
| `Invalid IAM Instance Profile name` at launch | IAM eventual consistency | Wait 10–20 s, retry |

## Commands to remember
| Goal | Command |
|---|---|
| Create / delete a cluster | `kind create cluster --name <n>` · `kind delete cluster --name <n>` |
| Load an image | `kind load docker-image <img> --name <n>` |
| Deploy | `kubectl apply -f day10/k8s/` |
| Everything for the app | `kubectl get deploy,rs,pods,svc -l app=capstone -o wide` |
| Watch pods | `kubectl get pods -l app=capstone -w` |
| Why is a pod failing | `kubectl describe pod <name>` (Events) |
| Scale | `kubectl scale deployment capstone --replicas=5` |
| Roll out / back | `kubectl set image deployment/capstone api=<img>` · `kubectl rollout undo deployment/capstone` |
| History | `kubectl rollout history deployment/capstone` |
| Reach the Service | `kubectl port-forward svc/capstone 8090:80` |
| EC2 shell without SSH | `aws ssm start-session --target <instance-id>` |
