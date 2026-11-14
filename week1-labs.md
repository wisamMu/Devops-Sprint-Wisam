# Week 1 — Labs and Solutions

The five labs from the sprint plan for Days 1–5. Each lab is followed by its solution — try it on your own first, then compare.

**Rules for every AWS lab:** Free plan only · region `us-east-1` · `t3.micro` · tag `Project=devops-sprint` · no SSH keys (Session Manager) · tear down the same day.

| Lab | Day | Topic | Solution |
|---|---|---|---|
| 1 | 1 | Linux on EC2 | ✅ Below |
| 2 | 2 | `healthcheck.sh` | ✅ Below |
| 3 | 3 | A VPC by hand | ✅ Below |
| 4 | 4 | Git workflow | ✅ Below |
| 5 | 5 | Break-fix drill | ✅ Below |

---

# Lab 1 (Day 1) — Linux on EC2
Launch an **Amazon Linux 2023** EC2 and connect through **Session Manager**, with **no SSH key**. Create **users and groups**, fix **file permissions**, and install **nginx** and manage it with **`systemctl`** and **`journalctl`**. Record every command in `linux.md`.

**Done when:** you connected without a key · two users share a group folder · four permission problems are fixed · nginx serves a page and starts on boot · `linux.md` holds every command · the instance is terminated.

## ✅ Solution 1

**1. An IAM role so the instance can use Session Manager (no keys)**
```bash
aws iam create-role --role-name sprint-ssm-role --assume-role-policy-document \
  '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
aws iam attach-role-policy --role-name sprint-ssm-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam create-instance-profile --instance-profile-name sprint-ssm-profile
aws iam add-role-to-instance-profile --instance-profile-name sprint-ssm-profile --role-name sprint-ssm-role
```
| Concept | Why |
|---|---|
| **Trust policy** | Lets the EC2 service *assume* the role |
| **`AmazonSSMManagedInstanceCore`** | The permissions the SSM agent needs to register and open sessions |
| **Instance profile** | The container that attaches a role to an instance |

**2. Launch with no key pair, IMDSv2 only**
```bash
AMI=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 --query Parameter.Value --output text)
ID=$(aws ec2 run-instances --image-id "$AMI" --instance-type t3.micro \
  --iam-instance-profile Name=sprint-ssm-profile \
  --metadata-options HttpTokens=required \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=day1},{Key=Project,Value=devops-sprint}]' \
  --query 'Instances[0].InstanceId' --output text)
aws ec2 wait instance-running --instance-ids "$ID"
```
Connect: **EC2 console → instance → Connect → Session Manager** (or `aws ssm start-session --target "$ID"` with the Session Manager plugin).

**3. Swap first (a `t3.micro` freezes during `dnf` without it)**
```bash
sudo fallocate -l 1G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile && free -m
```

**4. Users, groups and a shared folder**
```bash
sudo groupadd devops
sudo useradd -m -G devops alice
sudo useradd -m -G devops bob
id alice; getent group devops
sudo mkdir -p /srv/team
sudo chown root:devops /srv/team
sudo chmod 2770 /srv/team          # 2 = setgid: new files inherit the devops group
sudo usermod -aG wheel alice       # -a appends; without it, other groups are removed
```

**5. Fix permissions (the four classic problems)**
| Symptom | Cause | Fix |
|---|---|---|
| "bob can't read the config" | Owner-only mode, or bob not in the group | `sudo chgrp devops file && sudo chmod 640 file` · `sudo usermod -aG devops bob` (log in again) |
| "the script won't run" | No execute bit | `chmod +x script.sh` |
| "the folder blocks access" | Missing `x` on a parent folder | `namei -l /path/to/file` → `sudo chmod o+x /parent` |
| "the service can't read its config" | File owned by root, mode 600 | `sudo chown root:nginx file && sudo chmod 640 file` |

**6. nginx with systemctl and journalctl**
```bash
sudo dnf install -y nginx
rpm -qi nginx                      # package info
sudo systemctl enable --now nginx  # start now and on boot
systemctl status nginx
curl -I http://localhost           # → HTTP/1.1 200 OK
sudo nginx -t                      # test the config before a restart
sudo systemctl reload nginx        # re-read config, no downtime
journalctl -u nginx --since "10 min ago"
journalctl -u nginx -f             # follow live
```
| Break-fix | Find it | Fix |
|---|---|---|
| Broken config | `systemctl status nginx` → failed; `sudo nginx -t` names the line | Fix the line, `nginx -t`, `systemctl restart nginx` |
| Service stopped | `curl` → connection refused; `systemctl is-active nginx` → inactive | `sudo systemctl start nginx` |

**7. Teardown**
```bash
aws ec2 terminate-instances --instance-ids "$ID"
aws ec2 wait instance-terminated --instance-ids "$ID"
```
Full walkthrough: `day01/lab.md` on the `git-lab` branch.

---

# Lab 2 (Day 2) — `healthcheck.sh`
Write `healthcheck.sh` to check **disk usage**, **memory**, a **URL** and a **service**. It **exits non-zero on failure**, **logs with timestamps**, and passes **ShellCheck** cleanly.

**Done when:** all limits are configurable · a broken check makes it exit 1 · each line in the log starts with a date and time · `shellcheck` prints nothing.

## ✅ Solution 2

```bash
#!/usr/bin/env bash
# ^ shebang: run this file with bash (found via PATH). Nothing else may go on that line.
#
# healthcheck.sh - check disk, memory, a URL and a service.
# Exits 0 when every check passes, 1 when any check fails.

set -euo pipefail                                      # strict mode: stop on errors, unset vars, failed pipes

# ---- configuration (override with environment variables) ----
DISK_PATH="${DISK_PATH:-/}"                            # filesystem to check; default is root /
DISK_MAX_PCT="${DISK_MAX_PCT:-80}"                     # fail if disk usage is ABOVE this %
MEM_MIN_PCT="${MEM_MIN_PCT:-10}"                       # fail if available memory is BELOW this %
CHECK_URL="${CHECK_URL:-https://example.com}"          # URL that must answer 2xx or 3xx
CHECK_SERVICE="${CHECK_SERVICE:-cron}"                 # systemd service that must be active
LOG_FILE="${LOG_FILE:-./healthcheck.log}"              # where log lines are appended

passed=0                                               # counter of checks that passed
failed=0                                               # counter of checks that failed

log() {                                                # log LEVEL message... → timestamped line
  local level="$1"                                     # first argument: OK / FAIL / INFO
  shift                                                # drop it; "$*" is now the message
  printf '%s [%-4s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*" | tee -a "$LOG_FILE"   # print + append to the log file
}
pass() { log OK "$*"; passed=$(( passed + 1 )); }      # log OK and count it (not (( x++ )): that trips set -e at 0)
fail() { log FAIL "$*" >&2; failed=$(( failed + 1 )); }  # log FAIL to stderr and count it

check_disk() {                                         # is the disk too full?
  local used                                           # declare first, assign next (keeps the exit code, SC2155)
  used=$(df -P "$DISK_PATH" 2>/dev/null | awk 'NR==2 {gsub("%",""); print $5}') || true   # used % as a number; never crash
  if [[ -z $used ]]; then                              # no number → path missing or df failed
    fail "disk: no usage data for ${DISK_PATH}"
  elif (( used > DISK_MAX_PCT )); then                 # numeric compare: above the limit?
    fail "disk: ${DISK_PATH} is ${used}% used (limit ${DISK_MAX_PCT}%)"
  else                                                 # within the limit
    pass "disk: ${DISK_PATH} is ${used}% used (limit ${DISK_MAX_PCT}%)"
  fi
}

check_memory() {                                       # is there enough free memory?
  local avail_pct                                      # declare first, assign next
  avail_pct=$(free -m | awk '/^Mem:/ {printf "%d", $7 / $2 * 100}') || true   # available ÷ total × 100, as an integer
  if [[ -z $avail_pct ]]; then                         # free gave nothing
    fail "memory: no memory data"
  elif (( avail_pct < MEM_MIN_PCT )); then             # below the minimum?
    fail "memory: only ${avail_pct}% available (min ${MEM_MIN_PCT}%)"
  else                                                 # enough memory
    pass "memory: ${avail_pct}% available (min ${MEM_MIN_PCT}%)"
  fi
}

check_url() {                                          # does the URL answer correctly?
  local code                                           # will hold the HTTP status code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$CHECK_URL" 2>/dev/null) || true   # status only, 5 s limit, no crash
  if [[ $code =~ ^[23][0-9][0-9]$ ]]; then             # regex: 2xx or 3xx = healthy
    pass "url: ${CHECK_URL} returned ${code}"
  elif [[ $code == "000" || -z $code ]]; then          # 000 = no HTTP answer at all (DNS, refused, timeout)
    fail "url: ${CHECK_URL} is unreachable"
  else                                                 # 4xx / 5xx
    fail "url: ${CHECK_URL} returned ${code}"
  fi
}

check_service() {                                      # is the service running?
  local state                                          # will hold active / inactive / failed …
  if ! command -v systemctl >/dev/null 2>&1; then      # no systemd on this machine?
    fail "service: systemctl not available"
    return                                             # stop this check here
  fi
  state=$(systemctl is-active "$CHECK_SERVICE" 2>/dev/null) || true   # is-active exits non-zero when down; keep going
  if [[ $state == "active" ]]; then                    # running
    pass "service: ${CHECK_SERVICE} is active"
  else                                                 # anything else is a failure
    fail "service: ${CHECK_SERVICE} is ${state:-unknown}"
  fi
}

main() {                                               # entry point
  case "${1:-}" in                                     # look at the first argument (empty if none)
    -h|--help) echo "Usage: [VAR=value ...] $0"; exit 0 ;;   # help → print usage, success
    "") ;;                                             # no argument → run normally
    *) echo "Unknown option: $1" >&2; exit 2 ;;        # anything else → bad usage, exit 2
  esac
  log INFO "Health check started on $(hostname)"       # first log line names the machine
  check_disk                                           # run the four checks…
  check_memory
  check_url
  check_service
  if (( failed > 0 )); then                            # any check failed?
    log FAIL "Summary: ${passed} passed, ${failed} failed"
    exit 1                                             # non-zero → cron / CI notice the failure
  fi
  log INFO "Summary: ${passed} passed, 0 failed - all checks OK"   # all good; script ends with exit 0
}

main "$@"                                              # call main with all the script's arguments
```
**Test it**
```bash
shellcheck healthcheck.sh && echo "clean"
./healthcheck.sh; echo "exit=$?"                                  # → 0
DISK_MAX_PCT=0 ./healthcheck.sh; echo "exit=$?"                    # → 1 (disk)
CHECK_URL=http://localhost:9 ./healthcheck.sh; echo "exit=$?"      # → 1 (unreachable)
CHECK_SERVICE=nope ./healthcheck.sh; echo "exit=$?"                # → 1 (service)
./healthcheck.sh --bad; echo "exit=$?"                             # → 2 (bad usage)
```
| Requirement | How the script meets it |
|---|---|
| Non-zero on failure | Counts failures; `exit 1` if any |
| Timestamps | `printf` with `date '+%Y-%m-%d %H:%M:%S'`, `tee -a` to the log |
| Configurable | `${VAR:-default}` for every limit |
| Safe | `set -euo pipefail`, quoted variables, `$(( x + 1 ))` instead of `(( x++ ))` |
| ShellCheck clean | No warnings |

The repo copy (`day02/healthcheck.sh` on `git-lab`) is the same script with fuller comments and a longer `usage` text.

---

# Lab 3 (Day 3) — A VPC by hand
Build a VPC by hand: **2 public and 2 private subnets**, an **IGW** and **route tables**. Serve **nginx from the public subnet**. Explain in the README **why the private subnet has no internet access**, and **draw the NAT path** instead of paying for it.

**Done when:** nginx answers in your browser · the private route table shows only `local` · the README has the explanation and the NAT diagram · everything is deleted.

## ✅ Solution 3

```bash
export AWS_REGION=us-east-1
T() { echo "ResourceType=$1,Tags=[{Key=Name,Value=$2},{Key=Project,Value=devops-sprint}]"; }

# VPC + 4 subnets
VPC=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications "$(T vpc sprint-vpc)" --query Vpc.VpcId --output text)
aws ec2 modify-vpc-attribute --vpc-id "$VPC" --enable-dns-hostnames Value=true
PUB_A=$(aws ec2 create-subnet --vpc-id "$VPC" --cidr-block 10.0.1.0/24  --availability-zone us-east-1a --tag-specifications "$(T subnet public-a)"  --query Subnet.SubnetId --output text)
PUB_B=$(aws ec2 create-subnet --vpc-id "$VPC" --cidr-block 10.0.2.0/24  --availability-zone us-east-1b --tag-specifications "$(T subnet public-b)"  --query Subnet.SubnetId --output text)
PRIV_A=$(aws ec2 create-subnet --vpc-id "$VPC" --cidr-block 10.0.11.0/24 --availability-zone us-east-1a --tag-specifications "$(T subnet private-a)" --query Subnet.SubnetId --output text)
PRIV_B=$(aws ec2 create-subnet --vpc-id "$VPC" --cidr-block 10.0.12.0/24 --availability-zone us-east-1b --tag-specifications "$(T subnet private-b)" --query Subnet.SubnetId --output text)

# Internet gateway
IGW=$(aws ec2 create-internet-gateway --tag-specifications "$(T internet-gateway sprint-igw)" --query InternetGateway.InternetGatewayId --output text)
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW" --vpc-id "$VPC"

# Public route table: local + 0.0.0.0/0 → IGW
PUB_RT=$(aws ec2 create-route-table --vpc-id "$VPC" --tag-specifications "$(T route-table public-rt)" --query RouteTable.RouteTableId --output text)
aws ec2 create-route --route-table-id "$PUB_RT" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW"
aws ec2 associate-route-table --route-table-id "$PUB_RT" --subnet-id "$PUB_A"
aws ec2 associate-route-table --route-table-id "$PUB_RT" --subnet-id "$PUB_B"
aws ec2 modify-subnet-attribute --subnet-id "$PUB_A" --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id "$PUB_B" --map-public-ip-on-launch

# Private route table: local only
PRIV_RT=$(aws ec2 create-route-table --vpc-id "$VPC" --tag-specifications "$(T route-table private-rt)" --query RouteTable.RouteTableId --output text)
aws ec2 associate-route-table --route-table-id "$PRIV_RT" --subnet-id "$PRIV_A"
aws ec2 associate-route-table --route-table-id "$PRIV_RT" --subnet-id "$PRIV_B"

# Security group: HTTP from my IP only
MY_IP=$(curl -s https://checkip.amazonaws.com)
SG=$(aws ec2 create-security-group --group-name web-sg --description "HTTP from my IP" --vpc-id "$VPC" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 80 --cidr "$MY_IP/32"

# nginx in public-a (userdata.sh adds swap, installs and starts nginx)
AMI=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 --query Parameter.Value --output text)
ID=$(aws ec2 run-instances --image-id "$AMI" --instance-type t3.micro --subnet-id "$PUB_A" --security-group-ids "$SG" \
  --user-data file://userdata.sh --metadata-options HttpTokens=required --credit-specification CpuCredits=standard \
  --tag-specifications "$(T instance sprint-web)" --query 'Instances[0].InstanceId' --output text)
aws ec2 wait instance-running --instance-ids "$ID"
IP=$(aws ec2 describe-instances --instance-ids "$ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
sleep 120; curl -I "http://$IP"     # → HTTP/1.1 200 OK, Server: nginx
```

**Why the private subnets have no internet access**
| Requirement to reach the internet | Private subnet |
|---|---|
| IGW attached to the VPC | ✅ yes |
| Route `0.0.0.0/0 → IGW` in its route table | ❌ **only `local`** |
| Public IP on the instance | ❌ not assigned |

A packet to `8.8.8.8` from `10.0.11.7` finds no matching route except `local` (which doesn't match), so it's dropped. Traffic inside the VPC still works.

**The NAT path (drawn, not built — about $32/month)**
```text
Internet ◄──► IGW ◄── public-rt: 0.0.0.0/0 → IGW ──┐
                                                   │
             public-a: [ NAT gateway + Elastic IP ] ◄── rewrites source 10.0.11.7 → EIP
                                                   ▲
             private-rt: 0.0.0.0/0 → NAT ──────────┘
             private-a: [ EC2 10.0.11.7 ]  → outbound only; inbound from the internet is dropped
```

**Teardown, in reverse order**
```bash
aws ec2 terminate-instances --instance-ids "$ID" && aws ec2 wait instance-terminated --instance-ids "$ID"
aws ec2 delete-security-group --group-id "$SG"
for rt in "$PUB_RT" "$PRIV_RT"; do
  for a in $(aws ec2 describe-route-tables --route-table-ids "$rt" --query 'RouteTables[0].Associations[].RouteTableAssociationId' --output text); do
    aws ec2 disassociate-route-table --association-id "$a"
  done
  aws ec2 delete-route-table --route-table-id "$rt"
done
aws ec2 detach-internet-gateway --internet-gateway-id "$IGW" --vpc-id "$VPC"
aws ec2 delete-internet-gateway --internet-gateway-id "$IGW"
for s in "$PUB_A" "$PUB_B" "$PRIV_A" "$PRIV_B"; do aws ec2 delete-subnet --subnet-id "$s"; done
aws ec2 delete-vpc --vpc-id "$VPC"
```
Full walkthrough with every command explained: `day03/lab.md` on the `git-lab` branch.

---

# Lab 4 (Day 4) — Git workflow
Push Days 1–3 to your repo **using feature branches**. Open a **PR**, **review your own diff** before merging, and **resolve a deliberate merge conflict**. **Protect `main`** so nothing is pushed to it directly.

**Done when:** every day arrived through a merged PR · each PR has a self-review · one PR showed `CONFLICTING` and was fixed · a direct push to `main` is rejected.

## ✅ Solution 4

```bash
# 1. Protect main (and git-lab) on GitHub
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
for BRANCH in main git-lab; do
  gh api -X PUT "repos/$REPO/branches/$BRANCH/protection" --input - <<'EOF' > /dev/null
{"required_status_checks": null, "enforce_admins": true,
 "required_pull_request_reviews": {"required_approving_review_count": 0}, "restrictions": null}
EOF
done
git commit --allow-empty -m test && git push    # → GH006: Protected branch update failed
git reset --hard @{u}

# 2. One feature branch + PR per day
git switch git-lab && git pull
git switch -c docs/day01
git checkout origin/main -- day01
echo "| 1 | Linux | [day01](day01/README.md) |" >> SPRINT.md
git add SPRINT.md && git commit -m "docs: add Day 1 notes"
git push -u origin docs/day01
gh pr create --base git-lab --title "docs: add Day 1 notes" --body "Day 1 notes and index row."

# 3. Self-review, then merge
git diff --stat origin/git-lab...HEAD
git diff origin/git-lab...HEAD | grep -nE '\b[0-9]{12}\b|AKIA[0-9A-Z]{16}' || echo "no secrets found"
gh pr review --comment --body "Self-review: right files, no secrets."
gh pr merge --squash --delete-branch

# 4. A deliberate conflict: two branches edit the same line
#    (Day 3 merged first; Day 2 branched from BEFORE it → both append after row 1)
gh pr view --json mergeable -q .mergeable      # → CONFLICTING
git fetch origin && git merge origin/git-lab   # → CONFLICT in SPRINT.md
git checkout --theirs SPRINT.md                # take git-lab's rows
sed -i '/^| 1 |/a | 2 | Bash | [day02](day02/README.md) |' SPRINT.md   # put row 2 back, in order
git add SPRINT.md && git diff --cached --check && git commit --no-edit && git push
gh pr merge --squash --delete-branch
```
| Requirement | Shown by |
|---|---|
| Feature branches | One `docs/dayNN` branch per day |
| PR + self-review | `gh pr create`, `git diff --stat`, secrets scan, review comment |
| Deliberate conflict | `CONFLICTING` → merge `origin/git-lab` into the branch → resolve → `MERGEABLE` |
| `main` protected | Direct push → `GH006` |

Full walkthrough and lab log: `day04/lab.md` on the `git-lab` branch.

---

# Lab 5 (Day 5) — Break-fix drill
On a **fresh nginx VM**, write a script that applies **one of 4 faults at random** — **service stopped**, **wrong permissions**, **full disk**, **blocked port** — **without printing which one**. Run it, then **find and fix the fault within 60 minutes** and write a **5-line incident note**. Repeat until you have fixed all 4.

**Done when:** four incident notes exist, one per fault, each fixed within 60 minutes · the VM is terminated.

## ✅ Solution 5

**1. A fresh nginx VM** (no inbound rules needed: you test from inside with `curl localhost`)
```bash
AMI=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 --query Parameter.Value --output text)
ID=$(aws ec2 run-instances --image-id "$AMI" --instance-type t3.micro \
  --iam-instance-profile Name=sprint-ssm-profile \
  --user-data file://day03/userdata.sh \
  --metadata-options HttpTokens=required --credit-specification CpuCredits=standard \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=drill},{Key=Project,Value=devops-sprint}]' \
  --query 'Instances[0].InstanceId' --output text)
```
Connect with Session Manager, wait for `curl -I http://localhost` → `200 OK`, then copy `break.sh` (below) onto the VM with a heredoc and `chmod +x break.sh`.

**2. The fault script — `break.sh`**
```bash
#!/usr/bin/env bash
# ^ shebang: run this file with bash (found via PATH). Nothing else may go on that line.
#
# break.sh - apply ONE random nginx fault for the break-fix drill, without saying which.
# Run as root on the drill VM only:  sudo ./break.sh
# Faults: service stopped, wrong permissions, full disk, blocked port.
# Already-fixed faults are skipped, so repeat runs cover all 4.
# DRY_RUN=1 prints the commands instead of running them (safe anywhere).

set -euo pipefail                                      # strict mode: stop on errors, unset vars, failed pipes

STATE_DIR=/root/.drill                                 # where the answer and history live (root only)
DONE_FILE="$STATE_DIR/done"                            # faults already used, one per line
ANSWER_FILE="$STATE_DIR/answer"                        # the fault applied this time (check it AFTER fixing)
WEB_FILE=/usr/share/nginx/html/index.html              # the page nginx serves
FILL_FILE=/var/tmp/.cache-blob                         # hidden big file used to fill the disk

run() {                                                # run a command, or just print it in dry-run mode
  if [[ "${DRY_RUN:-0}" == "1" ]]; then                # DRY_RUN=1 → don't touch anything
    echo "DRY_RUN: $*"                                 # show what would run
  else
    "$@"                                               # really run the command with its arguments
  fi
}

fault_service() {                                      # fault 1: nginx is not running
  run systemctl stop nginx                             # → curl gets "connection refused"
}

fault_permissions() {                                  # fault 2: nginx can't read the page
  run chmod 600 "$WEB_FILE"                            # owner (root) only → nginx answers 403
}

fault_disk() {                                         # fault 3: the disk is (almost) full
  local avail_mb                                       # free space in MB
  avail_mb=$(df -Pm / | awk 'NR==2 {print $4}')        # read the "Available" column for /
  run fallocate -l "$(( avail_mb - 100 ))M" "$FILL_FILE"   # fill all but ~100 MB so SSM and the shell still work
}

fault_port() {                                         # fault 4: a firewall drops port 80
  command -v nft >/dev/null 2>&1 || run dnf install -y -q nftables   # install nft if it's missing
  run nft add table inet drill                         # our own firewall table (easy to find and delete)
  run nft add chain inet drill input '{ type filter hook input priority 0 ; }'   # hook it into incoming traffic
  run nft add rule inet drill input tcp dport 80 drop  # silently drop HTTP → curl times out
}

main() {                                               # entry point
  if [[ "${DRY_RUN:-0}" != "1" && $EUID -ne 0 ]]; then # real run but not root?
    echo "Run as root: sudo $0" >&2                    # explain on stderr
    exit 2                                             # bad usage
  fi

  mkdir -p "$STATE_DIR" && chmod 700 "$STATE_DIR"      # create the state folder, root-only
  touch "$DONE_FILE"                                   # make sure the history file exists

  local all=(service permissions disk port) left=() f  # the 4 faults, the ones left, a loop variable
  for f in "${all[@]}"; do                             # for each fault…
    grep -qx "$f" "$DONE_FILE" || left+=("$f")         # …keep it if it's not in the history yet
  done

  if (( ${#left[@]} == 0 )); then                      # all 4 already used?
    echo "All 4 faults done. Reset with: sudo rm -r $STATE_DIR"
    exit 0                                             # nothing left to do
  fi

  f=${left[RANDOM % ${#left[@]}]}                      # pick one remaining fault at random
  "fault_$f"                                           # call its function by name, e.g. fault_disk
  echo "$f" > "$ANSWER_FILE"                           # save the answer (not printed)
  echo "$f" >> "$DONE_FILE"                            # remember it, so it isn't picked again
  echo "A fault has been applied ($(( ${#left[@]} - 1 )) still to come after this one). Start your timer: 60 minutes."
}

main "$@"                                              # call main with all the script's arguments
```
| Part | Meaning |
|---|---|
| `run()` | Runs a command, or only prints it when `DRY_RUN=1` — test the script safely first |
| `fault_*` functions | One function per fault; `"fault_$f"` calls the chosen one by name |
| `left+=("$f")` | Builds the list of faults not done yet |
| `${left[RANDOM % ${#left[@]}]}` | Picks a random element: `RANDOM` modulo the list length |
| `/root/.drill/answer` | The answer, hidden from the screen; check it **after** you've fixed it: `sudo cat /root/.drill/answer` |
| `$EUID -ne 0` | Refuse to run without root (exit 2) |

**3. Finding the fault — the same triage every time**
```bash
curl -sS -o /dev/null -w '%{http_code}\n' --max-time 5 http://localhost   # what does the user see?
systemctl is-active nginx                                                 # is it running?
df -h /                                                                   # is the disk full?
sudo ss -tlnp | grep ':80'                                                # is it listening?
sudo tail -n 20 /var/log/nginx/error.log                                  # what does nginx say?
journalctl -u nginx -n 20 --no-pager
```
| Symptom from `curl` | Most likely | Confirm with |
|---|---|---|
| `Connection refused` / `000` fast | **Service stopped** | `systemctl is-active nginx` → `inactive` |
| `403` | **Wrong permissions** | `error.log`: `Permission denied`; `namei -l /usr/share/nginx/html/index.html` |
| Works, but writes fail / `No space left on device` | **Full disk** | `df -h /` → 99–100% |
| **Timeout** (hangs ~5 s), but `ss` shows nginx listening | **Blocked port** | `sudo nft list ruleset` |

**4. The fixes**
| Fault | Fix | Verify |
|---|---|---|
| Service stopped | `sudo systemctl start nginx` (and `enable` so a reboot doesn't repeat it) | `curl -I http://localhost` → 200 |
| Wrong permissions | `sudo chmod 644 /usr/share/nginx/html/index.html` | 200, and no new `Permission denied` |
| Full disk | Find the culprit: `sudo du -xh / --max-depth=3 2>/dev/null \| sort -h \| tail` or `sudo find / -xdev -size +500M -ls` → `sudo rm /var/tmp/.cache-blob` | `df -h /` back to normal |
| Blocked port | `sudo nft list ruleset` → `sudo nft delete table inet drill` | 200, no timeout |

**5. The 5-line incident note**
```text
What:   nginx on the drill VM returned 403 to every request (11:02).
Impact: The site was down for all users for 14 minutes.
Cause:  index.html was mode 600 (root-only), so the nginx worker couldn't read it.
Fix:    chmod 644 index.html; confirmed 200 OK and no new errors in error.log.
Prevent: Add a URL check (healthcheck.sh) and alert on non-2xx; deploy files with fixed modes.
```
| Line | Answers |
|---|---|
| What | What broke and when |
| Impact | Who was affected, how long |
| Cause | The **root** cause, not the symptom |
| Fix | What you changed, and how you verified it |
| Prevent | How to stop it happening again, or catch it sooner |

**6. Repeat, then tear down**
```bash
sudo ./break.sh          # again until it says "All 4 faults done"
aws ec2 terminate-instances --instance-ids "$ID"
```

---

# 📊 Do these labs cover Week 1?

Mostly. The labs practise the **core skills** of Days 1–4 well (about **70–75%** of what was studied), but a few topics never come up in them.

## What the labs test well ✅
| Day | Covered by |
|---|---|
| **1 · Linux** | Lab 1: filesystem, users and groups, `usermod -aG`, octal permissions, setgid, `namei -l`, `systemctl`, `journalctl`, `dnf`/`rpm`, Session Manager, IMDSv2, swap. Lab 5: troubleshooting a stopped service, permissions, a full disk. |
| **2 · Bash** | Lab 2: shebang, strict mode, variables, `${x:-default}`, functions and `local`, `if`/`[[ ]]`/`(( ))`, `case`, exit codes, pipes, `awk`, `curl`, `tee`, ShellCheck |
| **3 · Networking** | Lab 3: CIDR, subnets, route tables, IGW, public vs private, security groups, NAT (drawn). Lab 5: **refused vs timeout**, `ss`, firewalls. |
| **4 · Git** | Lab 4: branches, PRs, self-review, a conflict, `--theirs`, merge vs rebase (golden rule), branch protection, squash merges |

## Gaps: studied, but no lab uses them ⚠️
| Day | Not exercised |
|---|---|
| 1 | Signals (`kill` vs `kill -9`), jobs (`&`, `fg`, `bg`), `umask`, sticky bit |
| 2 | **Loops** (`for`, `while read`), **`grep`/`sed`** on real text, `trap`, here-documents, `cut`/`sort`/`uniq` pipelines |
| 3 | **DNS** (`dig`, record types, TTL), **TLS and certificates** (`openssl s_client`), **NACLs** (stateless, ephemeral ports), `traceroute`/`tcpdump` |
| 4 | `rebase`, `revert`, `reflog`, `stash`, tags, `.gitignore` patterns — only in the optional Git tasks, not the required lab |

# 🧩 Gap-filler — 45 minutes to full coverage

| # | Mini-task | Time | Covers |
|---|---|---|---|
| 1 | Top 5 client IPs from the nginx access log | 5 min | Pipes, `awk`, `sort`, `uniq` |
| 2 | `loop.sh`: loops, reading a file, cleanup with `trap` | 10 min | Loops, `trap`, here-docs |
| 3 | DNS and TLS from the command line | 10 min | `dig`, record types, TTL, certificates |
| 4 | A NACL that forgets the reply traffic | 10 min | Stateless NACLs, ephemeral ports |
| 5 | Git undo tools and tags | 10 min | `revert`, `reflog`, `stash`, tags |

## Gap 1 — Log pipeline (on the Lab 5 / Lab 3 instance)
```bash
for i in 1 2 3; do curl -s -o /dev/null http://localhost; done        # make a few requests
sudo awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -5   # top client IPs
sudo grep -c ' 404 ' /var/log/nginx/access.log                         # how many 404s
sudo sed -n '1,3p' /var/log/nginx/access.log                           # print only lines 1-3
```
| Part | Meaning |
|---|---|
| `awk '{print $1}'` | The 1st field of each line = the client IP |
| `sort \| uniq -c` | Group identical IPs and count them (`uniq` only merges **adjacent** lines, hence `sort` first) |
| `sort -rn \| head -5` | Biggest counts first, keep 5 |

## Gap 2 — `loop.sh` (in WSL)
```bash
cat > loop.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
tmp=$(mktemp)                                  # a temp file
trap 'rm -f "$tmp"; echo "cleaned up"' EXIT     # always delete it, even on error

for url in https://example.com https://github.com http://localhost:9; do   # for: a list
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$url") || true
  echo "$url $code" >> "$tmp"
done

while read -r url code; do                      # while read: line by line
  if [[ $code == 000 ]]; then echo "DOWN $url"; else echo "UP   $url ($code)"; fi
done < "$tmp"
EOF
chmod +x loop.sh && shellcheck loop.sh && ./loop.sh
```
**Expected:** two `UP` lines, one `DOWN http://localhost:9`, then `cleaned up`.

## Gap 3 — DNS and TLS
```bash
dig +short example.com                 # A record
dig example.com | grep -A1 'ANSWER SECTION'   # the TTL is the number after the name
dig MX gmail.com +short                # mail servers
dig +trace example.com | tail -5       # root → .com → authoritative
openssl s_client -connect example.com:443 -servername example.com </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates   # who it's for, who signed it, when it expires
curl -sv https://expired.badssl.com 2>&1 | grep -i 'expired'   # what a broken certificate looks like
```

## Gap 4 — A stateless NACL (during Lab 3, before teardown)
```bash
NACL=$(aws ec2 create-network-acl --vpc-id "$VPC" --query NetworkAcl.NetworkAclId --output text)
aws ec2 create-network-acl-entry --network-acl-id "$NACL" --ingress --rule-number 100 \
  --protocol tcp --port-range From=80,To=80 --cidr-block "$MY_IP/32" --rule-action allow
ASSOC=$(aws ec2 describe-network-acls --filters Name=association.subnet-id,Values="$PUB_A" \
  --query 'NetworkAcls[0].Associations[?SubnetId==`'"$PUB_A"'`].NetworkAclAssociationId' --output text)
NEW_ASSOC=$(aws ec2 replace-network-acl-association --association-id "$ASSOC" --network-acl-id "$NACL" \
  --query NewAssociationId --output text)
curl -m 5 "http://$IP"                 # → timeout: the reply to your ephemeral port is dropped

aws ec2 create-network-acl-entry --network-acl-id "$NACL" --egress --rule-number 100 \
  --protocol tcp --port-range From=1024,To=65535 --cidr-block "$MY_IP/32" --rule-action allow
curl -m 5 "http://$IP"                 # → works: NACLs are stateless, replies need their own rule
```
**Undo before teardown:** put the subnet back on the default NACL, then delete the custom one:
```bash
DEFAULT_NACL=$(aws ec2 describe-network-acls --filters Name=vpc-id,Values="$VPC" Name=default,Values=true \
  --query 'NetworkAcls[0].NetworkAclId' --output text)
aws ec2 replace-network-acl-association --association-id "$NEW_ASSOC" --network-acl-id "$DEFAULT_NACL"
aws ec2 delete-network-acl --network-acl-id "$NACL"
```

## Gap 5 — Git undo tools and tags (any practice repo)
```bash
echo a > a.txt && git add a.txt && git commit -m "chore: add a"
git revert HEAD --no-edit             # a new commit that undoes it
git reset --hard HEAD~2               # throw both away (local practice only)
git reflog | head -3                  # …and see where they went: @{1} = the revert, @{2} = "add a"
git reset --hard 'HEAD@{1}'           # bring both commits back (the revert sits on top of "add a")
echo wip >> a.txt && git stash && git stash pop   # shelve and restore work in progress
git tag -a v0.1 -m "practice tag" && git tag -n   # an annotated tag, listed with its message
```
