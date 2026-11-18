[⬅ Back to index](../README.md)

# Day 10 — Why Kubernetes Exists (Week 2 · Day 5, Checkpoint 2)

**Date:** 2026-11-18
**Topic:** Kubernetes — why it exists, the 4 words, desired state, cluster parts, `kubectl` and manifests, kind; plus instance profiles for the EC2 lab
**Reading:** "Why Kubernetes exists" (sprint plan) · [Kubernetes overview](https://kubernetes.io/docs/concepts/overview/) · [kind quick start](https://kind.sigs.k8s.io/docs/user/quick-start/)
**Cost:** kind is free (runs on the laptop). The EC2 lab (`t3.micro` + public IPv4, PAID-plan account) ≈ $0.016/hour → a few cents if terminated the same day.
**Lab (later):** morning — an EC2 with an instance profile (SSM + ECR read) pulls the image and runs it by hand. Afternoon — `kubectl` + kind, a Deployment with 3 replicas behind a Service; delete a pod, scale to 5, roll out a new tag and roll it back; 5 lines on what Kubernetes did that `docker run` on EC2 couldn't.
**Self-check 2:** PR checks green and enforced · SHA-tagged image in ECR via OIDC · the app answers `/health` on EC2 · on kind the app comes back after a pod is deleted.

| Part | Content |
|---|---|
| 📖 Cheat sheet | Manifest keys and `kubectl` / `kind` commands |
| Sections A–G | Definitions with examples |
| Check-your-understanding answers | All sections |
| Key takeaways | What to remember |

---

## 📖 Cheat sheet

### Manifest keys
| Key | Meaning | Example |
|---|---|---|
| `apiVersion` | API group/version for this kind | `apps/v1` (Deployment), `v1` (Service) |
| `kind` | Object type | `Deployment`, `Service` |
| `metadata.name` / `labels` | Name and key=value tags | `name: capstone`, `app: capstone` |
| `spec` | The desired state | `replicas: 3` |
| `spec.selector.matchLabels` | Which pods the Deployment owns | `app: capstone` |
| `spec.template` | The pod blueprint | labels + containers |
| `containers[].image` / `imagePullPolicy` | Image and when to download it | `capstone:v1`, `IfNotPresent` |
| `readinessProbe.httpGet` | Send traffic only when this answers | `/health` on 8000 |
| Service `selector` / `port` / `targetPort` | Which pods, Service port, pod port | `app: capstone`, `80` → `8000` |

### Commands
| Goal | Command |
|---|---|
| Create / delete a kind cluster | `kind create cluster --name capstone` · `kind delete cluster --name capstone` |
| Put a local image on the node | `kind load docker-image capstone:v1 --name capstone` |
| Apply manifests | `kubectl apply -f k8s/` |
| See things | `kubectl get pods -o wide` · `kubectl get deploy,rs,svc` |
| Why is it failing | `kubectl describe pod <name>` · `kubectl logs <pod>` |
| Self-healing test | `kubectl delete pod <name>` then `kubectl get pods -w` |
| Scale | `kubectl scale deployment capstone --replicas=5` |
| New version | `kubectl set image deployment/capstone api=capstone:v2` |
| Rollout | `kubectl rollout status` · `history` · `undo deployment/capstone` |
| Reach a ClusterIP Service | `kubectl port-forward svc/capstone 8090:80` |

---

## A — Why Kubernetes exists

`docker run` on one server works until there are **many containers on many servers** — nobody can watch each one. With Kubernetes you **declare the state you want** ("3 copies of this image, reachable on port 80") and it **keeps making reality match**.

| Problem with `docker run` on one server | What Kubernetes does | Name |
|---|---|---|
| The container crashes at 3 a.m. and stays down | Restarts it automatically | **Self-healing** |
| The server dies and takes the app with it | Moves the containers to healthy servers | **Rescheduling** |
| Traffic doubles; one copy isn't enough | More copies with one command, or automatically | **Scaling** |
| A new version means downtime | Replaces copies gradually; one command rolls back | **Rolling update / rollback** |
| Containers must find each other and share traffic | Stable name + load balancing | **Service** |
| Config and secrets copied around by hand | Injected at runtime | **ConfigMap / Secret** |

| Same situation | `docker run -d capstone` on EC2 | Deployment with `replicas: 3` |
|---|---|---|
| The process crashes | Stays down (unless `--restart`) | Restarted; the other 2 keep serving |
| Deleted by mistake | Gone until you re-run it | A new pod in seconds |
| Need 5 copies | 4 more commands, ports, your own load balancer | `kubectl scale … --replicas=5` |
| Version 2 is broken | Stop it, run v1 again (downtime) | `kubectl rollout undo …` |

> Not always the answer: one small app is often simpler on **EC2 or ECS**. Kubernetes pays off with **many services, teams and deployments**.

---

## B — The 4 words

| Word | Definition | Example |
|---|---|---|
| **Pod** | Smallest unit: one or more containers sharing an IP, living and dying together (usually 1) | 1 pod = 1 `capstone` container |
| **Deployment** | Keeps **N pods of one version** running; handles updates and rollbacks | `capstone`, `replicas: 3` |
| **Service** | Stable name + IP and a load balancer in front of a set of pods | port 80 → pods' 8000 |
| **Node** | A server in the cluster that runs pods | In kind: a Docker container |
| *Label* | key=value tag; Services and Deployments find pods by label | `app: capstone` |
| *ReplicaSet* | Created by the Deployment; counts pods. One per version → rollback | `capstone-7d9f…` |

```text
                Service "capstone" (stable name + IP, port 80)
                     │  selects pods with label app=capstone
        ┌────────────┼────────────┐
        ▼            ▼            ▼
      Pod #1       Pod #2       Pod #3     ← kept at 3 by the Deployment
        └──────── on Node(s) ─────┘
```

| Kubernetes | Docker world |
|---|---|
| Pod | A container from `docker run` |
| Deployment | `docker run` + a watcher that runs N copies and re-runs them |
| Service | Compose's service name (`db`) + a load balancer |
| Node | Your laptop / an EC2 running Docker |

> You never create pods by hand — create a Deployment and it creates them.

---

## C — Desired state

| Term | Definition | Example |
|---|---|---|
| **Imperative** | Step-by-step commands | `docker run …` three times |
| **Declarative** | Describe the end result; the system finds the steps | `replicas: 3` in YAML |
| **Desired state** | What you declared (stored in the cluster) | 3 pods of `capstone:v1` |
| **Current state** | What is actually running | 2 pods (one crashed) |
| **Controller** | A loop watching one kind of object and fixing differences | Deployment controller |
| **Reconciliation loop** | Observe → compare → act, forever | Sees 2, wants 3 → creates 1 |

| You do | Desired | Kubernetes does |
|---|---|---|
| Apply `replicas: 3` | 3 pods | Creates 3 |
| Delete a pod | Still 3 | Creates 1 → self-healing |
| `replicas: 5` | 5 | Adds 2 → scaling |
| New `image:` tag | 3 of the new tag | Gradual replace → rolling update |
| `rollout undo` | Old tag | Replace back → rollback |

Declarative = repeatable, reviewable in Git, self-correcting. Same idea as **Compose** and (Week 3) **Terraform**.

---

## D — The cluster's parts

| Part | Where | Job |
|---|---|---|
| **API server** | Control plane | The front door — `kubectl` and every component talk only to it |
| **etcd** | Control plane | Database of the cluster's state |
| **Scheduler** | Control plane | Picks the node for each new pod |
| **Controller manager** | Control plane | Runs the controllers (reconciliation loops) |
| **kubelet** | Each node | Starts the node's pods, reports their health |
| **Container runtime** | Each node | Runs the containers (containerd) |
| **kube-proxy** | Each node | Network rules so Services reach pods |

```text
kubectl apply -f deployment.yaml
 → API server saves it in etcd ("want 3")
 → Deployment controller sees 0/3 → creates 3 pod records
 → scheduler assigns nodes
 → kubelet starts the containers (runtime)
 → kube-proxy routes Service traffic to them
```

| Real cluster | kind | EKS (AWS) |
|---|---|---|
| Control plane servers | One container `capstone-control-plane` | Run by AWS (~$0.10/hour) |
| Worker nodes | Docker containers | EC2 instances |

---

## E — `kubectl` and YAML manifests

| Term | Definition | Example |
|---|---|---|
| **kubectl** | CLI that talks to the API server | `kubectl get pods` |
| **Manifest** | YAML declaring one or more objects | `k8s/deployment.yaml` |
| **Context** | Which cluster `kubectl` points at (`~/.kube/config`) | `kind-capstone` |
| **Namespace** | A folder inside a cluster | `default` |

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: capstone
spec:
  replicas: 3
  selector:
    matchLabels:
      app: capstone
  template:
    metadata:
      labels:
        app: capstone
    spec:
      containers:
        - name: api
          image: capstone:v1
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8000
          readinessProbe:
            httpGet:
              path: /health
              port: 8000
---
apiVersion: v1
kind: Service
metadata:
  name: capstone
spec:
  selector:
    app: capstone
  ports:
    - port: 80
      targetPort: 8000
```
| Line | Meaning |
|---|---|
| `replicas: 3` | Desired: 3 pods |
| `selector.matchLabels` | "My pods are labeled `app: capstone`" — must match the template's labels |
| `template:` | Pod blueprint |
| `imagePullPolicy: IfNotPresent` | Use the copy on the node (kind) instead of downloading |
| `containerPort: 8000` | uvicorn's port |
| `readinessProbe` `/health` | Traffic only after `/health` answers |
| `---` | Separates two objects in one file |
| Service `port: 80` → `targetPort: 8000` | Service port → pod port |
| No `type:` | **ClusterIP**: reachable only inside the cluster → use `kubectl port-forward` |

---

## F — kind: Kubernetes in Docker

| Term | Definition | Example |
|---|---|---|
| **kind** | A real Kubernetes cluster whose **nodes are Docker containers**; for learning and CI | `kind create cluster --name capstone` |
| **Node image** | `kindest/node:<version>` — containerd, kubelet, control plane | — |
| **`kind load docker-image`** | Copy an image from your Docker into the node's own containerd | `kind load docker-image capstone:v1 --name capstone` |

```text
Docker Desktop (capstone:v1)          kind node container
                                       └── its own containerd (empty)
        ── kind load docker-image ──►      capstone:v1
```
Without `kind load` the pods try Docker Hub → `ErrImagePull` / `ImagePullBackOff`.

| | kind | EKS |
|---|---|---|
| Where | Laptop | AWS |
| Nodes | Containers | EC2 |
| Cost | $0 | Control plane + nodes |
| Images | `kind load` | Pull from ECR |

---

## G — Instance profiles: EC2 pulls from ECR without keys

| Term | Definition | Example |
|---|---|---|
| **Instance profile** | Attaches an IAM role to an EC2 instance | `ec2-capstone-pull` |
| **EC2 role trust** | The EC2 service may assume the role | `"Principal": { "Service": "ec2.amazonaws.com" }` |
| **IMDS** | `169.254.169.254` inside the instance; the CLI gets the role's temporary keys here (IMDSv2) | Automatic |
| **`AmazonSSMManagedInstanceCore`** | Lets Session Manager connect — no SSH, no port 22 | Day 1 habit |
| **ECR read (pull)** | `GetAuthorizationToken`, `BatchGetImage`, `GetDownloadUrlForLayer`, `BatchCheckLayerAvailability` | Scoped to `capstone` |

| | Day 9: GitHub Actions | Day 10: EC2 |
|---|---|---|
| Who assumes the role | A workflow | The instance |
| Trust `Principal` | `Federated`: GitHub OIDC provider | `Service`: `ec2.amazonaws.com` |
| How it gets keys | OIDC token → STS | IMDS |
| Permissions | Push to `capstone` | Pull from `capstone` + SSM |
| Stored keys | None | None |

```text
role (SSM + ECR pull) ─instance profile─► EC2 t3.micro (Amazon Linux 2023)
   Session Manager → swap file → install Docker
   aws ecr get-login-password | docker login → docker pull …/capstone:<sha>
   docker run -d -p 8000:8000 … → curl localhost:8000/health → {"status":"ok"}
```
`curl` from inside → no inbound port opened. Terminate the same day.

---

## Check-your-understanding answers

| § | Question | Answer |
|---|---|---|
| A | "Crashed at 3 a.m." is handled by? | Self-healing |
| A | Desired state in one sentence? | You say *what* you want; Kubernetes keeps reality matching it |
| A | When not Kubernetes? | One small app — EC2 or ECS is simpler |
| B | A pod is deleted — who replaces it? | The Deployment (its ReplicaSet) |
| B | Why a Service, not a pod IP? | Pod IPs change; the Service is stable and load-balances |
| B | What links a Service to pods? | Labels (`selector`) |
| C | `kubectl scale --replicas=5` — imperative or declarative? | Imperative command that changes the desired state; YAML + `apply` is declarative |
| C | Who notices a deleted pod? | The controller, comparing desired vs current |
| C | Another declarative tool? | Compose; Terraform |
| D | `kubectl` talks to? | The API server only |
| D | Where is `replicas: 3` stored? | etcd |
| D | Who picks the node / starts the pod? | Scheduler / kubelet |
| E | Template labels ≠ selector? | Rejected: selector doesn't match template labels |
| E | Why `IfNotPresent` in kind? | The image is only on the node; pulling would fail |
| E | Browser to a ClusterIP Service? | No — `kubectl port-forward` |
| F | A node in kind is? | A Docker container |
| F | Skip `kind load`? | `ErrImagePull` / `ImagePullBackOff` |
| F | Delete the cluster? | `kind delete cluster --name capstone` |
| G | EC2 role's `Principal`? | `Service: ec2.amazonaws.com` |
| G | Where do the instance's keys come from? | IMDS |
| G | Why `curl` from inside? | No inbound port needed |

---

## Key takeaways

| Topic | Remember |
|---|---|
| Why | Many containers on many servers → declare desired state, Kubernetes keeps it |
| 4 words | Pod (unit) · Deployment (N pods, updates) · Service (stable address) · Node (server) |
| Labels | Glue between Services, Deployments and pods |
| Loop | Observe → compare → act; self-healing, scaling, rollouts are all this loop |
| Cluster | Control plane (API server, etcd, scheduler, controllers) + nodes (kubelet, runtime, kube-proxy) |
| Manifests | `apiVersion`, `kind`, `metadata`, `spec`; `kubectl apply -f` |
| kind | Nodes are containers; `kind load docker-image` before deploying |
| EC2 | Instance profile = role for a server; keys from IMDS; SSM, no SSH |
| When | Small app → EC2/ECS; many services and teams → Kubernetes |
