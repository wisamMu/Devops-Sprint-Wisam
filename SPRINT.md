# DevOps Sprint — Labs

The hands-on lab for each day. **Learning notes** (concepts, definitions, cheat sheets) live on the **`docs`** branch.

| Day | Lab | Files |
|---|---|---|
| 1 | Linux on EC2: Session Manager, users and groups, permissions, nginx with `systemctl` and `journalctl` | [lab](day01/lab.md) |
| 2 | `healthcheck.sh`: disk, memory, URL and service checks, exit codes, timestamped logs, ShellCheck | [lab](day02/lab.md), [healthcheck.sh](day02/healthcheck.sh) |
| 3 | A VPC by hand: 2 public + 2 private subnets, IGW, route tables, nginx, the NAT path | [lab](day03/lab.md), [userdata.sh](day03/userdata.sh) |
| 4 | Git workflow: protected branches, feature branches, PRs, self-review, a deliberate conflict | [lab](day04/lab.md) |
| 6 | Capstone API: FastAPI with `/health` and `/items`, 2 pytest tests, Dockerfile explained line by line | [lab](day06/lab.md), [capstone](capstone/README.md) |
| 7 | Docker done right: Alpine multi-stage image (117 MB, non-root) and a Compose stack with Postgres | [lab](day07/lab.md), [day07](day07/README.md) |
| 8 | CI with GitHub Actions: ruff, pytest, docker build and Trivy on every PR; failing checks block the merge | [lab](day08/lab.md), [workflow](.github/workflows/day08-ci.yml), [day08](day08/README.md) |
