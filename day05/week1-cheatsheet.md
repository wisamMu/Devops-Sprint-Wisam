# Week 1 — Lab Cheat Sheet

The commands you need for Labs 1–5, grouped by task. ⭐ = know by heart.

**Rules:** AWS Free plan · `us-east-1` · `t3.micro` · tag `Project=devops-sprint` · no SSH keys · tear down the same day.

---

## 1. AWS basics (all AWS labs)
| Goal | Command |
|---|---|
| Log in (browser) | `aws login` |
| Who am I? | `aws sts get-caller-identity --query Arn --output text` |
| Set the region | `export AWS_REGION=us-east-1` |
| Latest Amazon Linux 2023 AMI | `aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 --query Parameter.Value --output text` |
| Your instance profiles | `aws iam list-instance-profiles --query 'InstanceProfiles[].InstanceProfileName' --output text` |
| Launch (no key, IMDSv2, SSM) | `aws ec2 run-instances --image-id "$AMI" --instance-type t3.micro --iam-instance-profile Name=<profile> --metadata-options HttpTokens=required --credit-specification CpuCredits=standard --tag-specifications 'ResourceType=instance,Tags=[{Key=Project,Value=devops-sprint}]'` |
| Wait until running | `aws ec2 wait instance-running --instance-ids "$ID"` |
| Public IP | `aws ec2 describe-instances --instance-ids "$ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text` |
| Connect (no SSH) | EC2 console → Connect → **Session Manager**, or `aws ssm start-session --target "$ID"` |
| Delete it | `aws ec2 terminate-instances --instance-ids "$ID"` → `aws ec2 wait instance-terminated --instance-ids "$ID"` |
| Anything left running? | `aws ec2 describe-instances --filters Name=tag:Project,Values=devops-sprint Name=instance-state-name,Values=running,stopped --query 'Reservations[].Instances[].InstanceId'` |

## 2. Linux on the server (Lab 1, Lab 5)

### First thing on a t3.micro
| Goal | Command |
|---|---|
| Add 1 GB swap | `sudo fallocate -l 1G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile` |
| Check memory ⭐ | `free -m` |

### Users and groups
| Goal | Command |
|---|---|
| Create a group | `sudo groupadd devops` |
| Create a user with a home | `sudo useradd -m -s /bin/bash alice` |
| Add to a group ⭐ (keep `-a`!) | `sudo usermod -aG devops alice` |
| Give sudo | `sudo usermod -aG wheel alice` |
| Check a user ⭐ | `id alice` · `getent group devops` |
| Act as a user | `sudo -u bob cat /srv/team/plan.txt` |
| Delete a user | `sudo userdel -r alice` |

### Permissions
| Goal | Command |
|---|---|
| See permissions ⭐ | `ls -l file` · `ls -ld folder` |
| Set by number ⭐ | `chmod 644 file` (rw-r--r--) · `chmod 755 script` (rwxr-xr-x) · `chmod 640 secret` · `chmod 600 key` |
| Make executable ⭐ | `chmod +x script.sh` |
| Change owner ⭐ | `sudo chown alice:devops file` · `sudo chgrp devops file` |
| Shared team folder (setgid) | `sudo chown root:devops /srv/team && sudo chmod 2770 /srv/team` |
| Who blocks the path? | `namei -l /srv/team/plan.txt` |
| Octal | r = 4 · w = 2 · x = 1 → `7`=rwx `6`=rw- `5`=r-x `4`=r-- `0`=--- |

### Services: systemctl (control) vs journalctl (logs)
| Goal | Command |
|---|---|
| State + last log lines ⭐ | `systemctl status nginx` |
| One-word state (scripts) | `systemctl is-active nginx` · `systemctl is-enabled nginx` |
| Start now + at boot ⭐ | `sudo systemctl enable --now nginx` |
| Start / stop / restart ⭐ | `sudo systemctl start\|stop\|restart nginx` |
| Re-read config, no downtime | `sudo nginx -t && sudo systemctl reload nginx` |
| Logs of a service ⭐ | `journalctl -u nginx -n 50` |
| Follow live ⭐ | `journalctl -u nginx -f` |
| Time window / errors only | `journalctl -u nginx --since "10 min ago"` · `journalctl -u nginx -p err` |
| Failed services | `systemctl list-units --type=service --state=failed` |

### Packages
| Goal | Command |
|---|---|
| Install / remove | `sudo dnf install -y nginx` · `sudo dnf remove -y nginx` |
| Info / files / owner of a file | `rpm -qi nginx` · `rpm -ql nginx` · `rpm -qf /usr/sbin/nginx` |

### Disk, processes, ports
| Goal | Command |
|---|---|
| How full? ⭐ | `df -h` |
| What fills it? | `sudo du -xh / --max-depth=2 2>/dev/null \| sort -h \| tail` |
| Big files | `sudo find / -xdev -size +500M -ls 2>/dev/null` |
| Processes ⭐ | `ps aux \| grep nginx` · `top` |
| Stop a process | `kill <PID>` (polite) → `kill -9 <PID>` (forced, last resort) |
| Who listens on a port? ⭐ | `sudo ss -tlnp` · `sudo ss -tlnp \| grep :80` |
| Test the web server ⭐ | `curl -I http://localhost` |

## 3. Bash scripting (Lab 2)

### Script skeleton
```bash
#!/usr/bin/env bash
set -euo pipefail                         # stop on errors, unset vars, failed pipes
LIMIT="${LIMIT:-80}"                      # config with a default
log() { printf '%s [%s] %s\n' "$(date '+%F %T')" "$1" "$2" | tee -a run.log; }
main() {
  case "${1:-}" in -h|--help) echo "usage"; exit 0 ;; "") ;; *) exit 2 ;; esac
  # … checks …
}
main "$@"
```

### Patterns used in healthcheck.sh
| Goal | Code |
|---|---|
| Disk used % | `df -P / \| awk 'NR==2 {gsub("%",""); print $5}'` |
| Memory available % | `free -m \| awk '/^Mem:/ {printf "%d", $7 / $2 * 100}'` |
| HTTP status only | `curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$URL"` |
| Service state | `systemctl is-active "$SVC"` |
| Don't die when "failure" is an answer | `state=$(systemctl is-active "$SVC") \|\| true` |
| Number compare | `if (( used > LIMIT )); then …; fi` |
| String / regex test | `[[ -z $x ]]` · `[[ $code =~ ^[23][0-9][0-9]$ ]]` |
| Count safely under `set -e` | `n=$(( n + 1 ))` — not `(( n++ ))` |
| Error to stderr | `echo "FAIL …" >&2` |
| Exit codes | `0` ok · `1` a check failed · `2` bad usage |
| Lint ⭐ | `shellcheck script.sh` |
| Test a failure | `DISK_MAX_PCT=0 ./healthcheck.sh; echo $?` → `1` |

## 4. Networking and the VPC (Lab 3)

### Build order (tag everything)
| Step | Command |
|---|---|
| VPC | `aws ec2 create-vpc --cidr-block 10.0.0.0/16` |
| DNS names on | `aws ec2 modify-vpc-attribute --vpc-id "$VPC" --enable-dns-hostnames Value=true` |
| Subnet | `aws ec2 create-subnet --vpc-id "$VPC" --cidr-block 10.0.1.0/24 --availability-zone us-east-1a` |
| Internet gateway | `aws ec2 create-internet-gateway` → `aws ec2 attach-internet-gateway --internet-gateway-id "$IGW" --vpc-id "$VPC"` |
| Route table | `aws ec2 create-route-table --vpc-id "$VPC"` |
| **Make it public** | `aws ec2 create-route --route-table-id "$RT" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW"` |
| Attach to a subnet | `aws ec2 associate-route-table --route-table-id "$RT" --subnet-id "$SUBNET"` |
| Auto public IP | `aws ec2 modify-subnet-attribute --subnet-id "$SUBNET" --map-public-ip-on-launch` |
| Security group | `aws ec2 create-security-group --group-name web-sg --description "HTTP" --vpc-id "$VPC"` |
| Allow HTTP from me | `aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 80 --cidr "$(curl -s https://checkip.amazonaws.com)/32"` |
| Launch into it | add `--subnet-id "$SUBNET" --security-group-ids "$SG" --user-data file://userdata.sh` |
| Show routes | `aws ec2 describe-route-tables --route-table-ids "$RT" --query 'RouteTables[0].Routes[].[DestinationCidrBlock,GatewayId]' --output table` |

**Teardown order:** instance → security group → route tables (disassociate, delete) → IGW (detach, delete) → subnets → VPC.

### Reachable from the internet = all four
| ✔ | Requirement |
|---|---|
| 1 | IGW **attached** to the VPC |
| 2 | Route **`0.0.0.0/0 → IGW`** in the subnet's route table |
| 3 | A **public IP** on the instance |
| 4 | **SG** (and NACL) allow the port |

### Network checks
| Goal | Command |
|---|---|
| DNS ⭐ | `dig +short example.com` |
| Reachable? | `ping -c 4 8.8.8.8` |
| Port open? | `nc -zv host 443` |
| HTTP answer ⭐ | `curl -I https://example.com` · `curl -v …` |
| Certificate | `openssl s_client -connect host:443 -servername host </dev/null` |
| CIDR size | `/24` = 256 (251 usable in AWS) · `/16` = 65,536 |

| You see | It means | Look at |
|---|---|---|
| `Connection refused` | Reached the host, **nothing listening** | The service: `systemctl status`, `ss -tlnp` |
| **Timeout** | Packets **dropped** | Firewall (SG/NACL/nft) or route |
| `403` | Server refused: often **file permissions** | `error.log`, `namei -l` |
| `502 / 504` | Proxy can't reach / waited too long for the backend | The app behind the proxy |

## 5. Git workflow (Lab 4)
| Goal | Command |
|---|---|
| Start from the latest base ⭐ | `git switch labs && git pull` |
| New branch ⭐ | `git switch -c docs/day05` |
| Check before staging ⭐ | `git status -s` · `git diff` |
| Stage specific files ⭐ | `git add day05/lab.md SPRINT.md` (never `git add .` blindly) |
| Commit ⭐ | `git commit -m "docs: add Day 5 lab"` |
| Push the branch ⭐ | `git push -u origin docs/day05` |
| Open a PR | `gh pr create --base labs --title "docs: …" --body "…"` |
| Self-review | `git diff --stat origin/labs...HEAD` · `gh pr diff` |
| Secrets scan | `git diff origin/labs...HEAD \| grep -nE '\b[0-9]{12}\b\|AKIA[0-9A-Z]{16}' \|\| echo "no secrets found"` |
| Comment on it | `gh pr review --comment --body "Self-review: …"` |
| Merge + delete branch | `gh pr merge --squash --delete-branch` |
| Can it merge? | `gh pr view --json mergeable -q .mergeable` |
| Bring the base in (pushed branch) | `git fetch origin && git merge origin/labs` |
| List conflicted files | `git diff --name-only --diff-filter=U` |
| Take one side for a file | `git checkout --ours file` · `git checkout --theirs file` |
| Mark resolved, finish | `git add file && git diff --cached --check && git commit --no-edit` |
| Cancel a merge | `git merge --abort` |
| Protect a branch | `gh api -X PUT repos/<owner>/<repo>/branches/main/protection --input rules.json` |
| Undo: uncommitted / unpushed / pushed / lost | `git restore` · `git reset --soft HEAD~1` · `git revert <sha>` · `git reflog` |

## 6. Break-fix triage (Lab 5)
```bash
curl -sS -o /dev/null -w '%{http_code}\n' --max-time 5 http://localhost   # what the user sees
systemctl is-active nginx                                                 # running?
df -h /                                                                   # disk full?
sudo ss -tlnp | grep ':80'                                                # listening?
sudo tail -n 20 /var/log/nginx/error.log                                  # nginx's complaint
journalctl -u nginx -n 20 --no-pager                                      # systemd's view
```
| `curl` result | Suspect | Confirm | Fix |
|---|---|---|---|
| Refused / `000` at once | Service stopped | `systemctl is-active nginx` → inactive | `sudo systemctl enable --now nginx` |
| `403` | Permissions | `error.log`: Permission denied · `namei -l …` | `sudo chmod 644 /usr/share/nginx/html/index.html` |
| Works, but writes fail | Disk full | `df -h /` → 99–100% | Find the big file with `du` / `find`, then `rm` it |
| **Timeout**, yet `ss` shows :80 | Firewall | `sudo nft list ruleset` | `sudo nft delete table inet drill` |

**Incident note (5 lines):** What · Impact · Cause · Fix · Prevent.

**Method:** read the exact error → change **one** thing → verify → write it down.
