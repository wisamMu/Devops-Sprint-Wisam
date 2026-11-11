[⬅ Back to labs](../SPRINT.md)

> **Learning notes** for this day are on the **`docs`** branch: `day01/linux.md`.

# Day 1 — Linux Lab on EC2

**Date:** 2026-11-04
**Where:** Amazon Linux 2023 on EC2 (`us-east-1`), connected with Session Manager
**Goal:** Run and troubleshoot a real Linux server: users and permissions, processes, and a service (nginx) managed with `systemctl` and `journalctl`.
**Cost:** ~$0.05 of AWS Free plan credits (the EC2 ran about 1 hour). $0 paid.
**Learning first:** the concepts and WSL practice are on the `docs` branch (`day01/linux.md`).

**The task:** Launch an Amazon Linux 2023 EC2 and connect through Session Manager, with no SSH key. Create users and groups, fix file permissions, and install nginx and manage it with `systemctl` and `journalctl`. Record every command.

---

## What I built

| Area | Result |
|---|---|
| Learning | Linux Journey: Command Line, Text-Fu, User Management, Permissions, Processes — every command practised in WSL |
| IAM | Role `devops-sprint-ec2-ssm` with `AmazonSSMManagedInstanceCore` (kept for later days) |
| Server | `t3.micro`, Amazon Linux 2023, IMDSv2 only, no key pair, no inbound rules |
| Access | Session Manager in the browser — **no SSH key, port 22 closed** |
| Users | `alice`, `bob`, service user `webapp`, group `devops`, shared folder `/srv/project` |
| Service | nginx `1.30.6` installed with `dnf`, managed with `systemctl`, logs read with `journalctl`, `HTTP/1.1 200 OK` |
| Incidents | 4 real problems diagnosed and fixed, including a server freeze recovered from outside with SSM Run Command |
| Teardown | Instance terminated, security group deleted, nothing left running |

### Environment

| Item | Value |
|---|---|
| Local | Ubuntu 24.04.5 LTS in WSL 2 |
| Server OS | Amazon Linux 2023 (`2023.12.20261102`), kernel `6.18.56` |
| Instance type | `t3.micro` — 2 vCPU, ~1 GB RAM, 8 GiB gp3 disk |
| Region | `us-east-1` |
| SSM agent | `3.3.5700.0` |
| nginx | `1.30.6-1.amzn2023.0.1` |

---

## Step 1 — IAM role for Session Manager

**Why:** the server must be allowed to talk to AWS Systems Manager. An IAM role gives it **temporary credentials automatically** — no access keys on the server.

IAM → **Roles → Create role**:

| Setting | Value | Why |
|---|---|---|
| Trusted entity | **AWS service → EC2** | Only EC2 instances can use ("assume") this role |
| Policy | **`AmazonSSMManagedInstanceCore`** | Minimum permissions for the SSM agent |
| Name | `devops-sprint-ec2-ssm` | |
| Tag | `Project = devops-sprint` | Find and clean up later |

Verify from WSL:

```bash
aws iam get-role --role-name devops-sprint-ec2-ssm --query "Role.[RoleName,Arn]" --output table
```

| Part | Meaning |
|---|---|
| `aws iam get-role` | Ask IAM about one role |
| `--role-name` | The role |
| `--query "Role.[RoleName,Arn]"` | Pick only name and ARN (JMESPath syntax) |
| `--output table` | Readable table instead of JSON |

```bash
aws iam list-attached-role-policies --role-name devops-sprint-ec2-ssm --output table
```

- Lists attached policies → `AmazonSSMManagedInstanceCore` ✅

```bash
aws iam list-instance-profiles-for-role --role-name devops-sprint-ec2-ssm \
  --query "InstanceProfiles[].InstanceProfileName" --output text
```

- An **instance profile** is the container that attaches a role to an EC2 → `devops-sprint-ec2-ssm` ✅

**Cost:** $0. The role is kept and reused on later days.

---

## Step 2 — Launch the EC2

EC2 → **Launch instance** → **Launch without a walkthrough** (the walkthroughs change account-wide settings such as default backups).

| Setting | Value | Why |
|---|---|---|
| Name / tags | `day01-linux`, `Project = devops-sprint` on instance **and** volume | Easy to find and clean up |
| AMI | Amazon Linux 2023, 64-bit x86 | SSM agent pre-installed |
| Type | `t3.micro` | Free tier eligible |
| Key pair | **Proceed without a key pair** | No SSH — Session Manager instead |
| VPC / subnet | Default VPC, no preference | |
| Auto-assign public IP | **Enable** | The agent needs outbound internet; no NAT Gateway (costs money) |
| Security group | New `day01-linux-sg`, **default SSH rule removed → no inbound rules** | Nothing on the internet can connect in |
| Storage | 8 GiB gp3 | Default |
| Metadata version | **V2 only (token required)** | IMDSv2 — blocks credential theft via SSRF |
| IAM instance profile | `devops-sprint-ec2-ssm` | Attaches the Step 1 role |

**Key pair pop-up:** AWS warns "you will need it later to connect" — only true for SSH. Chose **Proceed without key pair**.

| | SSH with a key | Session Manager |
|---|---|---|
| Port 22 open | Yes | No |
| Private key to protect | Yes | None |
| Who can connect | Anyone with the key | IAM users allowed by policy; sessions logged |

**IMDSv2 warning** ("applications that use V1 will break") — normal and safe; Amazon Linux 2023, the SSM agent and the AWS CLI all support V2.

Verify:

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=day01-linux" "Name=instance-state-name,Values=pending,running" \
  --query "Reservations[].Instances[].[InstanceId,InstanceType,State.Name,PublicIpAddress,IamInstanceProfile.Arn]" \
  --output table
```

| Part | Meaning |
|---|---|
| `aws ec2 describe-instances` | List instances and details |
| `Name=tag:Name,Values=day01-linux` | Only instances with this Name tag |
| `Name=instance-state-name,Values=pending,running` | Skip terminated ones |
| `--query ...` | ID, type, state, public IP, instance profile |

Result: `i-05368bc65a83c04b4`, `t3.micro`, `running`, public IP, role attached ✅

```bash
aws ec2 describe-security-groups --filters "Name=group-name,Values=day01-linux-sg" \
  --query "SecurityGroups[].IpPermissions" --output json
```

| Part | Meaning |
|---|---|
| `describe-security-groups` | Show firewall rules |
| `IpPermissions` | **Inbound** rules |

Result: `[ [] ]` — no inbound rules ✅

---

## Step 3 — Connect with Session Manager

Check the agent has registered:

```bash
aws ssm describe-instance-information \
  --query "InstanceInformationList[].[InstanceId,PingStatus,PlatformName,AgentVersion]" --output table
```

| Part | Meaning |
|---|---|
| `describe-instance-information` | Instances Systems Manager knows about ("managed instances") |
| `PingStatus` | `Online` = agent connected |

Connect: EC2 → select `day01-linux` → **Connect → Session Manager → Connect**.

```text
Browser ──► AWS Systems Manager ◄── SSM agent on EC2 (uses the IAM role)
```

The agent connects **outbound**, so no inbound port is needed.

```bash
whoami
bash
cd ~ && pwd
cat /etc/os-release | head -3
hostname && uptime
id && sudo whoami
```

| Command | Meaning / result |
|---|---|
| `whoami` | `ssm-user` — created by the agent on first connect |
| `bash` | Session starts in `sh-5.2$`; Bash gives history, arrows, tab-completion. Prompt becomes `[ssm-user@ip-172-31-29-251 ~]$` (private IP) |
| `cd ~ && pwd` | `/home/ssm-user` |
| `cat /etc/os-release \| head -3` | `Amazon Linux`, `2023` |
| `hostname` | Name based on the private IP |
| `uptime` | Time running + load average |
| `id` | `uid=1001(ssm-user) groups=1001(ssm-user)` — not in `wheel` |
| `sudo whoami` | `root` — sudo works anyway (explained in Step 5) |
| `context=system_u:...` in `id` | **SELinux** security context — enabled by default |

### IMDSv2 in practice

```bash
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id; echo
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/info; echo
curl -s -o /dev/null -w "%{http_code}\n" http://169.254.169.254/latest/meta-data/instance-id
```

| Part | Meaning |
|---|---|
| `169.254.169.254` | Instance Metadata Service, reachable only from the instance |
| `TOKEN=$(...)` | Save the command's output in a variable |
| `curl -X PUT .../api/token` | Step 1 of IMDSv2: request a session token |
| `-H "...ttl-seconds: 300"` | Token valid 300 seconds |
| `-H "X-aws-ec2-metadata-token: $TOKEN"` | Step 2: send the token with each request |
| `.../instance-id` | Returns `i-05368bc65a83c04b4` ✅ |
| `.../iam/info` | Shows the attached role — how the agent gets credentials |
| `; echo` | Add a newline |
| `-o /dev/null -w "%{http_code}"` | Discard body, print only the HTTP status |
| Without token | **401** — V1 rejected ✅ |

---

## Step 4 — Filesystem

```bash
cd / && ls -la
```

| Folder | What lives there | Example |
|---|---|---|
| `/etc` | Configuration | `/etc/nginx/nginx.conf`, `/etc/passwd` |
| `/var/log` | Logs | `/var/log/amazon/ssm/`, `/var/log/nginx/` |
| `/var` | Changing data | caches, spools |
| `/home` | Users' folders | `/home/ssm-user` |
| `/root` | Root's home | |
| `/usr/bin` | Programs | `ls`, `curl`, `aws` |
| `/tmp` | Temporary files | sticky bit |
| `/opt` | Third-party software | |
| `/proc` | Virtual: kernel and process info | `/proc/meminfo` |
| `/dev` | Devices | `/dev/nvme0n1` (EBS disk) |

### Disks and space

```bash
lsblk
df -h
sudo du -sh /var/log/* 2>/dev/null | sort -h | tail -5
sudo du -xh / 2>/dev/null | sort -h | tail -10
```

| Part | Meaning |
|---|---|
| `lsblk` | **L**i**s**t **bl**oc**k** devices — `nvme0n1` 8G mounted at `/` |
| `df -h` | **D**isk **f**ree per filesystem; watch **Use%** (100% = "disk full") |
| `du -sh /var/log/*` | **D**isk **u**sage, one **s**ummary per item, **h**uman sizes |
| `2>/dev/null` | Hide permission errors |
| `sort -h \| tail -5` | Biggest 5 |
| `du -xh /` | Whole disk; `-x` stays on one filesystem (skips `/proc`) — first command for "disk full" |

### Find files

```bash
find /etc -name "*.conf" 2>/dev/null | head
sudo find /var/log -type f -size +1M
find /home/ssm-user -mmin -60
which curl && type cd
```

| Part | Meaning |
|---|---|
| `-type f -size +1M` | Regular files bigger than 1 MB |
| `-mmin -60` | **M**odified in the last 60 **min**utes |
| `which curl` | Where the program is — `/usr/bin/curl` |
| `type cd` | `cd` is a **shell builtin**, not a file |

### Logs

```bash
ls -la /var/log/
sudo tail -5 /var/log/amazon/ssm/amazon-ssm-agent.log
```

- Most system logs on Amazon Linux 2023 are in the **systemd journal** (`journalctl`, Step 8).
- The SSM agent log is where to look if Session Manager fails.

### System info

```bash
cat /proc/cpuinfo | grep "model name" | head -1
grep -E "MemTotal|MemAvailable" /proc/meminfo && free -h
nproc
```

| Command | Meaning |
|---|---|
| `/proc/cpuinfo` | CPU model — generated by the kernel when read |
| `/proc/meminfo` | Memory details (~1 GB total) |
| `free -h` | Friendly memory summary, including **swap** |
| `nproc` | Number of CPU cores — 2 |

### Links

```bash
ls -l /bin
ln -s /var/log ~/logs && ls -l ~/logs && ls ~/logs | head -3
```

| Part | Meaning |
|---|---|
| `/bin -> usr/bin` | `/bin` is a **symbolic link** (`l` type) |
| `ln -s TARGET LINK` | Create a symlink `~/logs` → `/var/log` |

---

## Step 5 — Users and groups

### Who's on the server?

```bash
whoami && id
awk -F: '$3 >= 1000 {print $1, $3, $6, $7}' /etc/passwd
awk -F: '$3 < 1000 {print $1, $7}' /etc/passwd | head
```

| Part | Meaning |
|---|---|
| `$3 >= 1000` | Real users: `ec2-user` (1000, AWS default), `ssm-user` (1001, SSM agent) |
| `$3 < 1000` | System users, mostly `/sbin/nologin` |
| `{print $1, $3, $6, $7}` | Name, UID, home, shell |

### How ssm-user gets sudo

```bash
getent group wheel
sudo grep -v "^#" /etc/sudoers | grep -E "wheel|includedir"
sudo ls -l /etc/sudoers.d/ && sudo cat /etc/sudoers.d/ssm-agent-users
sudo -l
```

| Part | Meaning |
|---|---|
| `getent group wheel` | `wheel` = admin group on Amazon Linux; ssm-user isn't in it |
| `%wheel ALL=(ALL) ALL` | Members of `wheel` can run anything |
| `#includedir /etc/sudoers.d` | Also load every file in that folder — the `#` is part of the directive |
| `/etc/sudoers.d/ssm-agent-users` | `ssm-user ALL=(ALL) NOPASSWD:ALL` — sudo without a password |
| `sudo -l` | **L**ist what I may run with sudo |

### Create a group and users

```bash
sudo groupadd devops
sudo useradd -m -s /bin/bash -G devops alice && sudo useradd -m -s /bin/bash bob
sudo useradd -r -s /sbin/nologin webapp
id alice && id bob && id webapp && getent group devops
```

| Part | Meaning |
|---|---|
| `-m` / `-s /bin/bash` / `-G devops` | Home folder / Bash / supplementary group |
| `-r` | System (service) user, no home |
| `-s /sbin/nologin` | No login |

### Modify users

```bash
sudo usermod -aG devops bob && id bob
sudo usermod -c "Alice Developer" alice && getent passwd alice
```

| Part | Meaning |
|---|---|
| `-aG devops` | **Append** group — never `-G` without `-a` |
| `-c "..."` | Comment field (full name), field 5 of `/etc/passwd` |

### Switch users

```bash
sudo -iu alice
whoami && pwd && sudo ls /root
exit
sudo -u bob whoami
sudo -iu webapp
```

| Command | Result |
|---|---|
| `sudo -iu alice` | Login shell as alice |
| `whoami && pwd` | `alice`, `/home/alice` |
| `sudo ls /root` | "lecture" message, then `[sudo] password for alice:` — **no password exists**, so "Sorry, try again" ×3 → "3 incorrect password attempts". Even with a password she'd be refused — not in `wheel`. `Ctrl+C`, `exit` |
| `sudo -u bob whoami` | `bob` — one command as bob, no shell |
| `sudo -iu webapp` | "unable to change directory to /home/webapp" (no home) + "This account is currently not available" (`nologin`) |

### Grant and revoke admin rights

```bash
sudo usermod -aG wheel alice && id alice
sudo gpasswd -d alice wheel && id alice
```

| Part | Meaning |
|---|---|
| `usermod -aG wheel alice` | Alice becomes an admin — `10(wheel)` appears |
| `gpasswd -d alice wheel` | **D**elete alice from `wheel` only — "Removing user alice from group wheel" |

### Logins

```bash
who && last -n 5
```

| Command | Result |
|---|---|
| `who` | Empty — Session Manager sessions aren't recorded as logins |
| `last -n 5` | Only `reboot system boot ... still running` |

---

## Step 6 — Permissions on the server

```text
-rw-r----- 1 alice devops ...      r=4  w=2  x=1
 owner group others                rw- r-- --- = 640
```

### Team folder

```bash
sudo mkdir -p /srv/project && sudo chown root:devops /srv/project && sudo chmod 2770 /srv/project && ls -ld /srv/project
```

| Part | Meaning |
|---|---|
| `/srv` | Standard place for data a server serves |
| `chown root:devops` | Owner root, group devops |
| `chmod 2770` | setgid + owner/group full, others nothing → `drwxrws---` |

### Scenario 1 — "bob can't read the config"

```bash
sudo -iu alice bash -c 'echo "db_host=localhost" > /srv/project/app.conf && chmod 600 /srv/project/app.conf'
sudo -u bob cat /srv/project/app.conf                    # Permission denied
ls -l /srv/project/app.conf && id bob                    # investigate
sudo chmod 640 /srv/project/app.conf && sudo -u bob cat /srv/project/app.conf   # fixed
sudo -u ec2-user cat /srv/project/app.conf               # still denied — correct
```

- **Cause:** `-rw------- alice devops` — group has no read.
- **Fix:** `640`. The file's group is `devops`, not `alice` — the setgid folder at work.

### Scenario 2 — "the script won't run"

```bash
echo -e '#!/bin/bash\necho "Deploying as $(whoami)"' | sudo tee /srv/project/deploy.sh && sudo chgrp devops /srv/project/deploy.sh
sudo -u bob /srv/project/deploy.sh            # Permission denied
ls -l /srv/project/deploy.sh                  # -rw-r--r-- — no x
sudo chmod 750 /srv/project/deploy.sh && sudo -u bob /srv/project/deploy.sh   # "Deploying as bob"
```

| Part | Meaning |
|---|---|
| `echo -e` | Turn `\n` into a real new line |
| `#!/bin/bash` | **Shebang** — run this file with Bash |
| `$(whoami)` | Replaced with the username when the script runs |
| `sudo tee FILE` | Write the file as root |
| `chgrp devops` | File's group |
| `750` | Owner `rwx`, group `r-x`, others nothing |

### Scenario 3 — "the folder blocks access"

```bash
sudo mkdir -p /srv/project && sudo chmod 2760 /srv/project && echo "x" | sudo tee /srv/project/app.conf >/dev/null && sudo chmod 644 /srv/project/app.conf
sudo chown root:devops /srv/project && ls -ld /srv/project      # drwxrwS--- root devops
sudo -u bob cat /srv/project/app.conf                           # Permission denied
namei -l /srv/project/app.conf                                  # shows the folder lacks x
sudo chmod 2770 /srv/project && sudo -u bob cat /srv/project/app.conf   # prints x
```

| Part | Meaning |
|---|---|
| `2760` | Group has `rw-` but **no `x`** on the folder |
| Capital `S` | setgid on, `x` off |
| `namei -l PATH` | Permissions of **every folder on the path** at once |
| Lesson | To reach a file you need `x` on every folder in its path |

### Scenario 4 — "the service can't read its config"

```bash
sudo mkdir -p /opt/webapp && echo "port=8080" | sudo tee /opt/webapp/config.env >/dev/null && sudo chmod 600 /opt/webapp/config.env
sudo -u webapp cat /opt/webapp/config.env                       # denied — owned by root
sudo chown webapp:webapp /opt/webapp/config.env && sudo -u webapp cat /opt/webapp/config.env   # port=8080
```

- Give the file to the service user instead of `chmod 777`.

### Special bits and umask

```bash
ls -ld /tmp && ls -l /usr/bin/passwd
umask
```

| Seen as | Meaning |
|---|---|
| `drwxrwxrwt` | Sticky bit |
| `-rwsr-xr-x` | Setuid |
| `0022` | New files `644`, folders `755` |

### Summary

| # | Symptom | Investigation | Cause | Fix |
|---|---|---|---|---|
| 1 | bob can't read `app.conf` | `ls -l`, `id bob` | Group no read (`600`) | `chmod 640` |
| 2 | Script "Permission denied" | `ls -l` | No `x` | `chmod 750` |
| 3 | Denied though file is `644` | `namei -l` | Folder group no `x` | `chmod 2770` |
| 4 | Service can't read config | `ls -l` | Owned by root | `chown webapp:webapp` |

---

## Step 7 — Processes on the server

```bash
ps -p 1 -o pid,comm
systemctl list-units --type=service --state=running --no-pager
```

| Part | Meaning |
|---|---|
| `ps -p 1 -o pid,comm` | PID 1 = **systemd** |
| `systemctl list-units` | Units known to systemd |
| `--type=service --state=running` | Only running services |
| `--no-pager` | Print all at once |

21 running services, including:

| Service | Purpose |
|---|---|
| `amazon-ssm-agent` | Session Manager / Run Command |
| `sshd` | SSH server (running, but port 22 is blocked by the security group) |
| `chronyd` | Time sync (NTP) |
| `systemd-journald` | Log collection |
| `systemd-resolved` | DNS resolution |
| `auditd` | Security auditing |
| `atd` | Scheduled one-off jobs |

All other process commands (`ps aux`, `jobs`, `kill`, `top`, `ss`) were practised in Section 5.

---

## Step 8 — Packages and systemd (nginx)

### Theory

**Packages:** a package bundles a program, its files, its config and its **dependencies**. A **package manager** downloads it from a **repository** and keeps track of it.

| | Amazon Linux / Red Hat | Ubuntu / Debian |
|---|---|---|
| Package manager | **`dnf`** (formerly `yum`) | `apt` |
| Format | `.rpm` | `.deb` |
| Low-level tool | `rpm` | `dpkg` |

**systemd:** PID 1 — starts and supervises **services** described by **unit files**. `systemctl` controls it; `journalctl` reads its logs.

### Prepare: swap (added after Incident 3)

```bash
sudo dd if=/dev/zero of=/swapfile bs=1M count=1024 status=progress
sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile && free -h
```

| Part | Meaning |
|---|---|
| `dd` | Copy raw data |
| `if=/dev/zero` | Input: endless zeros |
| `of=/swapfile` | Output file |
| `bs=1M count=1024` | 1024 × 1 MB = 1 GB |
| `status=progress` | Show progress |
| `chmod 600` | Root-only (swap can hold sensitive memory) |
| `mkswap` | Format as swap |
| `swapon` | Start using it |
| `free -h` | `Swap: 1.0Gi` ✅ |

### Find and inspect a package

```bash
dnf search nginx | head -5
dnf info nginx
dnf repolist
```

| Command | Meaning |
|---|---|
| `dnf search nginx` | Search repositories by name/description |
| `dnf info nginx` | Version, size, repository, description |
| `dnf repolist` | Repositories: `amazonlinux`, `kernel-livepatch` |

### Install

```bash
sudo dnf install -y nginx
```

| Part | Meaning |
|---|---|
| `sudo` | Installing needs root |
| `dnf install nginx` | Download nginx **and dependencies** (`nginx-core`, `nginx-filesystem` …) |
| `-y` | Auto-confirm |
| Done when | `Complete!` |

### Inspect what was installed

```bash
rpm -qi nginx | head -8
rpm -ql nginx-core | grep -E "bin|etc" | head
rpm -qf /etc/nginx/nginx.conf
dnf history | head -5
```

| Part | Meaning |
|---|---|
| `rpm -q` | **Q**uery installed packages |
| `-i` | **I**nfo — version `1.30.6`, install date, size |
| `-ql` | **L**ist installed files — `/usr/sbin/nginx`, `/etc/nginx/...` |
| `-qf FILE` | Which package owns this **f**ile |
| `dnf history` | Install/update history |

### Control the service

```bash
systemctl status nginx --no-pager                     # inactive (dead)
sudo systemctl start nginx && systemctl is-active nginx
systemctl is-enabled nginx                            # disabled
sudo systemctl enable nginx && systemctl is-enabled nginx
systemctl status nginx --no-pager
ps -o user,pid,ppid,cmd -C nginx
```

| Command | Meaning |
|---|---|
| `status` | State, main PID, processes, recent logs |
| `start` / `stop` | Run now / stop now |
| `enable` / `disable` | Start / don't start at boot |
| `enable --now` | Both at once |
| `is-active` / `is-enabled` | One-word answers for scripts |
| `ps ... -C nginx` | Master runs as **root**, workers as user **`nginx`** — workers' PPID = master's PID |

| Running now? | At boot? | Command |
|---|---|---|
| ✅ | — | `start` |
| ❌ | — | `stop` |
| — | ✅ | `enable` |
| — | ❌ | `disable` |
| ✅ | ✅ | `enable --now` |

Reading `systemctl status`:

| Line | Meaning |
|---|---|
| `Loaded: ... nginx.service; enabled` | Unit file location, enabled |
| `Active: active (running) since ...` | Running and for how long |
| `Main PID:` | Master process |
| `CGroup:` | All its processes |

### Test it

```bash
curl -s localhost | grep -i "<title>"
curl -sI localhost | head -3
sudo ss -tlnp | grep nginx
```

| Command | Result |
|---|---|
| `curl -s localhost` | Home page HTML; the `<title>` line |
| `curl -sI` | Headers only — `HTTP/1.1 200 OK`, `Server: nginx` |
| `ss -tlnp` | nginx listening on port **80** — not reachable from the internet (no inbound rule) |

### Unit file

```bash
systemctl cat nginx
```

| Line | Meaning |
|---|---|
| `[Unit] After=network-online.target` | Start after the network is up |
| `ExecStartPre=/usr/sbin/nginx -t` | Test config before starting |
| `ExecStart=/usr/sbin/nginx` | Start command |
| `ExecReload=... -s reload` | What `reload` does |
| `[Install] WantedBy=multi-user.target` | What `enable` hooks into |

### Reload vs restart

```bash
sudo systemctl reload nginx && systemctl status nginx --no-pager | grep "Main PID"
sudo systemctl restart nginx && systemctl status nginx --no-pager | grep "Main PID"
```

| Command | What happens | Main PID |
|---|---|---|
| `reload` | Re-read config, no downtime | Same |
| `restart` | Full stop + start, brief outage | Changes |

### Logs with journalctl

```bash
sudo journalctl -u nginx --no-pager
sudo journalctl -u nginx -n 5 --no-pager
sudo journalctl -u nginx --since "10 minutes ago" --no-pager
sudo journalctl -p err -b --no-pager | tail -10
sudo tail -3 /var/log/nginx/access.log
```

| Part | Meaning |
|---|---|
| `-u nginx` | Only the nginx **u**nit |
| `-n 5` | Last 5 lines |
| `--since "10 minutes ago"` | Time filter |
| `-p err` | **P**riority error or worse, all services |
| `-b` | Since last **b**oot |
| `/var/log/nginx/access.log` | nginx's own request log — my `curl` calls |

### Break-fix A — broken config

```bash
echo "this is broken" | sudo tee -a /etc/nginx/nginx.conf      # break
sudo systemctl restart nginx                                    # "Job for nginx.service failed"
systemctl status nginx --no-pager                               # 1. state: failed
sudo journalctl -u nginx -n 15 --no-pager                       # 2. logs: the error
sudo nginx -t                                                   # 3. config test: file + line
curl -sI localhost                                              # site down
sudo tail -2 /etc/nginx/nginx.conf                              # confirm the bad line
sudo sed -i '$d' /etc/nginx/nginx.conf                          # fix
sudo nginx -t && sudo systemctl restart nginx && curl -sI localhost | head -1   # 200 OK
```

| Part | Meaning |
|---|---|
| `tee -a` | **A**ppend as root |
| `nginx -t` | **T**est config without starting |
| `sed -i '$d'` | **S**tream **ed**itor, in place: `$` last line, `d` delete |

- **Prevention:** always run `nginx -t` before a restart or reload.

### Break-fix B — service stopped

```bash
sudo systemctl stop nginx && curl -sI localhost                 # Connection refused
systemctl is-active nginx; sudo ss -tlnp | grep :80              # inactive, nothing on :80
sudo systemctl start nginx && curl -sI localhost | head -1       # 200 OK
```

### Remove and reinstall

```bash
sudo dnf remove -y nginx && which nginx; systemctl status nginx --no-pager | head -2
sudo dnf install -y nginx && sudo systemctl enable --now nginx && curl -sI localhost | head -1
```

### Final state (checked through SSM Run Command)

| Check | Result |
|---|---|
| Package | `nginx-1.30.6-1.amzn2023.0.1.x86_64` |
| Service | `active`, `enabled` |
| HTTP | `HTTP/1.1 200 OK` |
| Swap | `1.0Gi` |

My 3 checks for a broken service: **`systemctl status` → `journalctl -u` → `nginx -t`**.

---

## Step 9 — Teardown

**Why:** a running EC2 and its public IP use credits by the hour. Terminating deletes the server and its disk.

```bash
aws ec2 terminate-instances --instance-ids i-05368bc65a83c04b4 \
  --query "TerminatingInstances[].[InstanceId,CurrentState.Name]" --output table
```

| Part | Meaning |
|---|---|
| `terminate-instances` | Permanently delete the instance and its disk |
| `--query` | Show ID and new state (`shutting-down`) |

Verify nothing is left:

```bash
aws ec2 describe-instances --filters "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query "Reservations[].Instances[].[InstanceId,State.Name]" --output table
aws ec2 describe-addresses --query "Addresses[].PublicIp" --output text
aws ec2 describe-volumes --filters "Name=status,Values=available" --query "Volumes[].VolumeId" --output text
aws ec2 delete-security-group --group-name day01-linux-sg
```

| Command | Checks | Result |
|---|---|---|
| `describe-instances` (non-terminated) | Any instance still alive | none ✅ |
| `describe-addresses` | Elastic IPs (cost money when unused) | none ✅ |
| `describe-volumes status=available` | Unattached disks | none ✅ |
| `delete-security-group` | Tidy up (free anyway) | deleted ✅ |

| Resource | Kept? | Why |
|---|---|---|
| IAM role `devops-sprint-ec2-ssm` | ✅ | Free, reused on Days 3, 10, 13 |
| IAM user `wisam-admin` | ✅ | Daily login |
| Budget alert | ✅ | Protects credits |

**Stop vs terminate:** a stopped instance still keeps its disk (uses credits); terminate removes everything.
**Session vs instance:** "Terminate session" closes only the browser terminal; "Terminate instance" deletes the server.

---

## What broke and how I fixed it

| # | Problem | Cause | Fix |
|---|---|---|---|
| 1 | bob still denied after `chmod 2770` | bob wasn't in `devops`; folder group was `root` | `chown root:devops /srv/project`, `usermod -aG devops bob` |
| 2 | dnf "Waiting for process with pid 3692 to finish" | `Ctrl+Z` **paused** a slow `dnf search`, which kept the package lock | New session → `pgrep -a dnf` → `sudo pkill -9 dnf` |
| 3 | Server froze; new sessions showed a black screen | `dnf` used all 1 GB RAM; no swap | Reboot from outside, add 1 GB swap, reinstall |
| 4 | `sudo` asked alice for a password, failed 3× | Expected — no password, not in `wheel` | `Ctrl+C`, `exit` |

### Incident 1 — bob still denied

- **Symptom:** `sudo -u bob cat /srv/project/app.conf` → Permission denied, even after `chmod 2770`.
- **Investigation:** `namei -l /srv/project/app.conf` — folder fine; `id bob` — no `devops`.
- **Cause:** bob had never been added to `devops`, and the folder's group was initially `root`.
- **Fix:** `sudo chown root:devops /srv/project` and `sudo usermod -aG devops bob`.
- **Lesson:** check **both sides** — the path (`ls -l`, `namei -l`) **and** the user (`id`).

### Incident 2 — dnf lock

- **Symptom:** `dnf info` and `sudo dnf install` hung: "Waiting for process with pid 3692 to finish".
- **Investigation:** `[1]+ Stopped dnf search nginx`.
- **Cause:** the first `dnf search` downloads ~87 MB of metadata and was slow; `Ctrl+Z` paused it instead of stopping it, and a paused dnf still holds the lock. `Ctrl+C` didn't get through the browser terminal either.
- **Fix:** opened a second session, then:

  ```bash
  bash
  pgrep -a dnf                              # list dnf processes
  sudo pkill -9 dnf                         # SIGKILL works on paused processes
  pgrep -a dnf || echo "no dnf running"     # || runs only if pgrep found nothing
  ```

- **Lesson:** `Ctrl+C` stops, `Ctrl+Z` pauses. "Waiting for process X" = another dnf/apt holds the lock.

### Incident 3 — server froze (out of memory)

- **Symptom:** the terminal stopped responding; even a new session opened a black screen that accepted no input.
- **Investigation from WSL** (outside the server):

  ```bash
  aws ec2 describe-instance-status --instance-ids i-05368bc65a83c04b4 --include-all-instances \
    --query "InstanceStatuses[].[InstanceState.Name,SystemStatus.Status,InstanceStatus.Status]" --output table
  aws ssm describe-instance-information --filters "Key=InstanceIds,Values=i-05368bc65a83c04b4" \
    --query "InstanceInformationList[].[PingStatus,LastPingDateTime]" --output table
  aws ec2 get-console-output --instance-id i-05368bc65a83c04b4 --latest --output text --query Output | tail -25
  ```

  | Command | Meaning | Result |
  |---|---|---|
  | `describe-instance-status` | AWS health checks of the host and the OS | `running`, `ok`, `ok` |
  | `describe-instance-information` | Is the SSM agent connected? | `Online` |
  | `get-console-output` | The server's boot log (like looking at its screen) | Showed boot time — no reboot yet |

- **Remote diagnosis with SSM Run Command** (no session needed):

  ```bash
  aws ssm send-command --instance-ids i-05368bc65a83c04b4 --document-name AWS-RunShellScript \
    --parameters 'commands=["uptime","free -m","pgrep -a dnf || echo no-dnf"]' \
    --query Command.CommandId --output text
  aws ssm get-command-invocation --command-id <id> --instance-id i-05368bc65a83c04b4 \
    --query StandardOutputContent --output text
  ```

  | Part | Meaning |
  |---|---|
  | `send-command` | Run commands on the instance through the agent |
  | `AWS-RunShellScript` | Built-in "run these shell commands" document |
  | `--parameters 'commands=[...]'` | The commands |
  | `get-command-invocation` | Read the status and output |

- **Cause:** `dnf` loading package metadata used up the ~1 GB RAM of `t3.micro`, which had **no swap**.
- **Fix:**

  ```bash
  aws ec2 reboot-instances --instance-ids i-05368bc65a83c04b4    # from WSL — kills dnf, frees memory, keeps the disk
  ```

  After the reboot: `up 0 min`, 639 MB available, `no-dnf`. Terminated the dead session, reconnected, added the 1 GB swap file (Step 8) and installed nginx successfully.
- **Lessons:**
  - Small instances need swap before heavy tools like dnf.
  - When the shell is unreachable, diagnose from **outside**: status checks → SSM agent → Run Command.
  - Reboot keeps the disk (users, files); terminate deletes everything.
  - A session opened before/during a reboot is dead — terminate it and reconnect.
  - SSM Run Command is how the Day 13 pipeline will deploy the app.

### Incident 4 — alice and sudo

- **Symptom:** `[sudo] password for alice:` → "Sorry, try again" → "3 incorrect password attempts".
- **Cause:** expected. sudo asks for the **current user's** password; alice has none and isn't in `wheel`.
- **Lesson:** least privilege — normal users can't become root.

---

## Key takeaways

| Topic | Remember |
|---|---|
| Access | Session Manager + IAM role = no keys, no open ports |
| Disk | `df -h` (how full) → `du -xh / \| sort -h` (what's filling it) |
| Users | `useradd -m -s /bin/bash`, `usermod -aG` (never `-G` alone), service users with `nologin` |
| sudo | `wheel` group or a file in `/etc/sudoers.d/`; edit only with `visudo` |
| Permissions | `x` on every folder in the path; check with `namei -l`; never `chmod 777` |
| Processes | `kill` before `kill -9`; `Ctrl+C` stops, `Ctrl+Z` pauses |
| Packages | `dnf install/remove/info`, `rpm -qi/-ql/-qf` |
| systemd | `start` ≠ `enable`; `reload` keeps the PID; `nginx -t` before restart |
| Troubleshooting | `systemctl status` → `journalctl -u` → config test |
| Cost | Terminate at the end of the day; check instances, Elastic IPs, volumes |

## Self-check

- [x] Connected to EC2 with **no SSH key and no port 22**, and can explain how
- [x] Read `-rw-r-----` as `640`
- [x] Explained why bob was denied and fixed it
- [x] Explained why `usermod -G` without `-a` is dangerous
- [x] Debugged a failed service with `systemctl status`, `journalctl -u`, `nginx -t`
- [x] EC2 terminated, nothing left running
