[⬅ Back to labs](../SPRINT.md)

# Day 10 — The Same Image on EC2 and on Kubernetes (kind)

The Day 8 app (`capstone`), run two ways: **by hand on an EC2** that pulls from ECR with an instance profile, and as a **Kubernetes Deployment** on a local kind cluster. Full steps: [lab.md](lab.md).

| File | What |
|---|---|
| [k8s/deployment.yaml](k8s/deployment.yaml) | Deployment `capstone`: 3 replicas of `capstone:v1`, readiness probe on `/health` |
| [k8s/service.yaml](k8s/service.yaml) | Service `capstone`: ClusterIP, port 80 → pods' 8000 |
| [lab.md](lab.md) | The lab write-up: EC2 morning + kind afternoon |

## What Kubernetes did that `docker run` on EC2 couldn't

1. **Self-healing:** a deleted pod was replaced within seconds, because the Deployment keeps 3 running; a `docker run` container on EC2 stays gone until someone re-runs it.
2. **Scaling:** one command (`kubectl scale --replicas=5`) added 2 copies, and the Service sent traffic to them automatically; on EC2 each copy needs its own `docker run`, port and a load balancer.
3. **Stable address:** the Service kept one IP (`10.96.x.x`) while pod IPs changed on every replacement; on EC2 clients would have to track each container themselves.
4. **Rolling update:** `kubectl set image` replaced pods gradually with no downtime, gated by the readiness probe; on EC2 a new version means stop, remove, run — a gap in service.
5. **Rollback:** `kubectl rollout undo` went back in one command, reusing the old ReplicaSet with no rebuild; on EC2 you re-run the old tag by hand and hope you remember which one.

## Run it
```bash
kind create cluster --name capstone
docker build -t capstone:v1 ../day08 && docker tag capstone:v1 capstone:v2
kind load docker-image capstone:v1 capstone:v2 --name capstone
kubectl apply -f k8s/
kubectl rollout status deployment/capstone
kubectl port-forward svc/capstone 8090:80     # then: curl localhost:8090/health
kind delete cluster --name capstone
```
