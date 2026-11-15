# Week 1 — What We Learnt (Days 1–4)

Definitions and core concepts from Linux, Bash, Networking, and Git & GitHub.

---

# Day 1 — Linux Essentials

## The system
| Term | Definition | Example |
|---|---|---|
| **Linux** | An operating system kernel; with its tools it forms a *distribution* (Amazon Linux, Ubuntu). | `uname -sr` → `Linux 6.18.56` |
| **Kernel** | The core of the OS: manages CPU, memory, devices and processes. Programs talk to it through system calls. | `uname -r` → kernel version |
| **Shell** | A program that reads your commands and runs them (Bash is the most common). | `echo $SHELL` → `/bin/bash` |
| **Terminal** | The window that hosts the shell. | Windows Terminal running WSL |
| **Distribution (distro)** | Kernel + package manager + tools, packaged together. | `cat /etc/os-release` → `Amazon Linux 2023` |

## Filesystem
| Term | Definition | Example |
|---|---|---|
| **Filesystem hierarchy** | One tree starting at `/` (root). Everything — disks, devices, processes — appears somewhere in it. | `ls /` → `bin etc home proc tmp usr var …` |
| **`/etc`** | System configuration files. | `cat /etc/hostname` |
| **`/var`** | Variable data; `/var/log` holds logs. | `ls /var/log` |
| **`/home`** | Users' personal folders. `/root` is the root user's home. | `ls /home` → `alice bob` |
| **`/usr/bin`, `/bin`** | Installed programs. | `which ls` → `/usr/bin/ls` |
| **`/tmp`** | Temporary files, cleared on reboot. | `touch /tmp/test.txt` |
| **`/proc`** | A virtual filesystem showing live kernel and process information. | `cat /proc/meminfo \| head -3` |
| **Absolute vs relative path** | Absolute starts at `/` (`/etc/hosts`); relative starts where you are (`logs/app.log`). `.` = here, `..` = parent, `~` = home. | `cd /var/log` (absolute) · `cd ..` (relative) · `cd ~` |
| **Hidden file** | A name starting with `.` (`.bashrc`), shown with `ls -a`. | `ls -a ~` → `.bashrc .profile …` |
| **Mount** | Attaching a disk or volume to a folder in the tree. | `df -h` → which disk is mounted on `/` |
| **Inode** | The record of a file's metadata (owner, permissions, size, location); the name is just a pointer to it. | `ls -i file.txt` → inode number |

## Users and groups
| Term | Definition | Example |
|---|---|---|
| **User** | An identity with a UID. Every file and process belongs to one. Listed in `/etc/passwd`. | `sudo useradd -m alice` · `id alice` |
| **Group** | A set of users with a GID, used to share access. Listed in `/etc/group`. | `sudo groupadd devops` · `getent group devops` |
| **Primary vs secondary group** | The primary group owns new files you create; secondary groups give extra access. | `id alice` → `gid=1001(alice) groups=1001(alice),1002(devops)` |
| **root** | The superuser (UID 0); bypasses permission checks. | `sudo whoami` → `root` |
| **sudo** | Run one command as root. Allowed by `/etc/sudoers` (and files in `/etc/sudoers.d/`). | `sudo systemctl restart nginx` |
| **`wheel` group** | On Amazon Linux/RHEL, members may use `sudo`. | `sudo usermod -aG wheel alice` |
| **Principle of least privilege** | Give each user only the access they need. | bob gets `devops`, not `wheel` |

## Permissions
| Term | Definition | Example |
|---|---|---|
| **r / w / x** | Read, write, execute. On a **folder**: r = list names, w = create/delete files, x = enter it. | `ls -l` → `-rw-r--r-- notes.txt` |
| **Owner / group / others** | The three classes each file has permissions for. | `sudo chown alice:devops report.txt` |
| **Octal notation** | r=4, w=2, x=1, summed per class: `750` = rwx r-x ---, `644` = rw- r-- r--. | `chmod 750 deploy.sh` · `chmod 644 index.html` |
| **umask** | Bits removed from new files' default permissions. | `umask` → `0022` → new files are `644` |
| **setuid** | A program runs with its **owner's** rights (e.g. `passwd`). | `ls -l /usr/bin/passwd` → `-rwsr-xr-x` |
| **setgid (on a folder)** | New files inherit the folder's **group** — good for shared team folders. | `sudo chmod 2770 /srv/team` |
| **Sticky bit** | In a shared folder, only a file's owner can delete it (e.g. `/tmp`). | `ls -ld /tmp` → `drwxrwxrwt` |
| **Path traversal rule** | To reach a file you need `x` on **every** folder above it (`namei -l` shows each step). | `namei -l /srv/team/plan.txt` |

## Processes
| Term | Definition | Example |
|---|---|---|
| **Process** | A running instance of a program, with a **PID**, an owner and a state. | `ps aux \| grep nginx` |
| **Parent / child (PPID)** | Every process is started by another; PID 1 (systemd) is the ancestor. | `ps -o pid,ppid,cmd -p $$` · `pstree -p \| head` |
| **Foreground / background** | Foreground holds the terminal; background (`&`) doesn't. `Ctrl+Z` suspends, `bg`/`fg` resume. | `sleep 100 &` · `jobs` · `fg %1` |
| **Signal** | A message to a process. **SIGTERM (15)**: please stop. **SIGKILL (9)**: stop now, can't be caught. **SIGINT**: `Ctrl+C`. **SIGHUP**: reload. | `kill 1234` (TERM) · `kill -9 1234` · `pkill sleep` |
| **Zombie** | A finished process whose parent hasn't collected its exit code. | `ps aux` → state `Z` |
| **Load average** | Average number of processes running or waiting, over 1, 5 and 15 minutes. | `uptime` → `load average: 0.10, 0.05, 0.01` |

## Services, logs and packages
| Term | Definition | Example |
|---|---|---|
| **Daemon** | A background service (name often ends in `d`: `sshd`, `crond`). | `systemctl list-units --type=service --state=running` |
| **systemd** | The init system (PID 1): starts, stops and supervises services. | `ps -p 1 -o comm=` → `systemd` |
| **Unit** | Anything systemd manages; a `.service` file describes how to run a service. | `systemctl cat nginx` |
| **start vs enable** | `start` = run it now; `enable` = run it at every boot. `enable --now` does both. | `sudo systemctl enable --now nginx` · `systemctl is-enabled nginx` |
| **journald / journal** | systemd's central log store, read with `journalctl`. | `journalctl -u nginx -n 20` · `journalctl -u nginx -f` |
| **Package** | A bundle of a program, its files and metadata (`.rpm` on Amazon Linux, `.deb` on Ubuntu). | `rpm -qi nginx` · `rpm -ql nginx \| head` |
| **Package manager** | Installs, updates and removes packages and their **dependencies** from **repositories** (`dnf`, `apt`). | `sudo dnf install -y nginx` · `sudo dnf remove nginx` |
| **Dependency** | Another package a program needs to run. | `dnf repoquery --requires nginx` |

## Memory
| Term | Definition | Example |
|---|---|---|
| **RAM** | Fast working memory for running processes. | `free -m` → `total 949` |
| **Swap** | Disk space used as overflow memory — slow, but prevents freezing when RAM runs out. | `sudo fallocate -l 1G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile` |
| **OOM killer** | The kernel kills a process when memory is exhausted. | `journalctl -k \| grep -i "out of memory"` |
| **Available memory** | Memory that can be given to programs now, including reclaimable cache. | `free -m` → the `available` column |

## Linux on AWS
| Term | Definition | Example |
|---|---|---|
| **EC2 instance** | A virtual machine in AWS. | `aws ec2 describe-instances --filters Name=tag:Project,Values=devops-sprint` |
| **AMI** | The machine image an instance boots from (e.g. Amazon Linux 2023). | `aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64` |
| **IAM role / instance profile** | Permissions given to an instance itself, so it needs no stored keys. | `--iam-instance-profile Name=sprint-ssm-profile` on `run-instances` |
| **Session Manager** | Shell access to an instance through AWS, with **no SSH key and no open port 22**. | `aws ssm start-session --target i-0abc…` (or EC2 console → Connect) |
| **IMDS / IMDSv2** | The instance metadata service at `169.254.169.254`; v2 requires a session token, blocking SSRF-style theft. | `TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60")` |
| **User data** | A script an instance runs once, as root, on first boot. | `--user-data file://userdata.sh` |
| **Stop vs terminate** | Stop = paused, disk kept. Terminate = deleted for good. | `aws ec2 stop-instances --instance-ids i-0abc…` · `aws ec2 terminate-instances --instance-ids i-0abc…` |

---

# Day 2 — Bash Scripting

## Shell basics
| Term | Definition | Example |
|---|---|---|
| **Bash** | The "Bourne Again SHell": an interactive shell and a scripting language. | `bash --version` |
| **Script** | A text file of commands run in order. | `echo 'echo hello' > hi.sh` · `bash hi.sh` → `hello` |
| **Shebang** | First line `#!/usr/bin/env bash`: tells the OS which interpreter runs the file. | `head -1 healthcheck.sh` → `#!/usr/bin/env bash` |
| **Executable bit** | `chmod +x` lets a script be run as `./script.sh`. | `chmod +x hi.sh` · `./hi.sh` |
| **PATH** | The list of folders the shell searches for commands. | `echo $PATH` · `which curl` |
| **Environment variable** | A variable passed down to child processes (`export NAME=value`). | `export LOG_FILE=/tmp/h.log` · `env \| grep LOG_FILE` |

## Streams and redirection
| Term | Definition | Example |
|---|---|---|
| **stdin / stdout / stderr** | Standard input (0), output (1) and error (2) — the three streams every process has. | `ls /etc /nope` → listing on stdout, error on stderr |
| **Pipe `\|`** | Sends one command's stdout into the next command's stdin. | `ps aux \| grep nginx` |
| **`>` / `>>`** | Write stdout to a file (overwrite / append). | `date > now.txt` · `date >> history.txt` |
| **`2>` / `2>&1`** | Redirect stderr / merge stderr into stdout. | `ls /nope 2> err.txt` · `cmd > all.log 2>&1` |
| **`/dev/null`** | A "black hole" that discards whatever is written to it. | `curl -s -o /dev/null https://example.com` |
| **Here-document `<<EOF`** | Feeds several lines as input to a command. Quoted `'EOF'` stops variable expansion. | `cat > note.txt <<'EOF'` … `EOF` |
| **tee** | Writes input to the screen **and** a file at once. | `echo "started" \| tee -a run.log` |

## Text tools
| Term | Definition | Example |
|---|---|---|
| **grep** | Prints lines that match a pattern. | `grep -n "error" app.log` · `grep -v "^#" config` |
| **sed** | Stream editor: substitutes, deletes or inserts text line by line. | `sed 's/http/https/g' urls.txt` · `sed -i '/^$/d' file` |
| **awk** | Splits each line into fields (`$1`, `$2`…) and runs small programs on them. | `df -P / \| awk 'NR==2 {print $5}'` → `23%` |
| **Regular expression (regex)** | A pattern language: `^` start, `$` end, `.` any char, `*` repeat, `[0-9]` a class, `\|` or (in `-E` extended mode). | `grep -E '^(ERROR\|WARN)' app.log` |
| **cut / sort / uniq / wc** | Pick columns / sort lines / collapse duplicates / count lines, words, bytes. | `cut -d' ' -f1 access.log \| sort \| uniq -c \| sort -rn \| head` · `wc -l app.log` |

## Variables and expansion
| Term | Definition | Example |
|---|---|---|
| **Variable** | `name=value` (no spaces around `=`); read with `"$name"`. | `name=wisam` · `echo "Hi $name"` |
| **Quoting** | Double quotes keep spaces together but expand `$vars`; single quotes keep everything literal. Unquoted variables split on spaces — a common bug. | `echo "$HOME"` → `/home/wmusleh` · `echo '$HOME'` → `$HOME` |
| **Command substitution** | `$(command)` is replaced by the command's output. | `today=$(date +%F)` · `echo "$today"` |
| **Arithmetic expansion** | `$(( a + b ))` does integer math. | `echo $(( 7 * 6 ))` → `42` |
| **Parameter expansion** | `${x:-default}` (use a default), `${x#prefix}` (strip a prefix), `${#x}` (length). | `echo "${PORT:-80}"` · `f=report.txt; echo "${f%.txt}"` → `report` |
| **Positional parameters** | `$1`, `$2`… the script's arguments; `$@` all of them; `$#` how many. | `./greet.sh Ali` → inside: `echo "Hello $1"` |
| **local** | A variable that exists only inside a function. | `f() { local x=5; }` |

## Control flow
| Term | Definition | Example |
|---|---|---|
| **Exit code** | A number every command returns: **0 = success**, anything else = failure. `$?` holds the last one. | `ls /nope; echo $?` → `2` |
| **`&&` / `\|\|`** | Run the next command only if the previous one succeeded / failed. | `mkdir logs && cd logs` · `ping -c1 host \|\| echo "down"` |
| **`if` / `[[ … ]]`** | Branch on a test: strings, files (`-f`, `-d`), regex (`=~`). | `if [[ -f /etc/hosts ]]; then echo yes; fi` |
| **`(( … ))`** | Numeric comparison and math (`(( x > 80 ))`). | `used=91; if (( used > 80 )); then echo "disk high"; fi` |
| **case** | Branch on a value matching patterns — tidy for command-line options. | `case "$1" in -h\|--help) usage ;; *) run ;; esac` |
| **for / while** | Loop over a list / loop while a condition is true (`while read line`). | `for f in *.log; do wc -l "$f"; done` · `while read -r line; do echo "$line"; done < file` |
| **Function** | A named, reusable block of commands. | `greet() { echo "Hi $1"; }` · `greet Ali` |

## Robust scripts
| Term | Definition | Example |
|---|---|---|
| **`set -e`** | Stop the script when a command fails. | `set -e; false; echo "never printed"` |
| **`set -u`** | Treat an unset variable as an error. | `set -u; echo "$NOPE"` → `unbound variable` |
| **`set -o pipefail`** | A pipeline fails if **any** command in it fails, not just the last. | `set -o pipefail; false \| true; echo $?` → `1` |
| **Strict mode** | `set -euo pipefail` together. Trap: `(( x++ ))` returns 1 when x was 0, which stops the script. | `x=0; (( x++ )); echo $?` → `1` — use `x=$(( x + 1 ))` |
| **trap** | Runs a command when the script exits or receives a signal (cleanup). | `trap 'rm -f "$tmp"' EXIT` |
| **Idempotent** | Running it twice gives the same result as once — a goal for automation. | `mkdir -p logs` (no error the 2nd time) |
| **Linter (ShellCheck)** | A tool that finds bugs and bad patterns without running the script. | `shellcheck healthcheck.sh` |
| **Health check** | A script that tests a system (disk, memory, URL, service) and reports through its exit code. | `./healthcheck.sh; echo $?` → `0` healthy, `1` a check failed |

---

# Day 3 — Networking for DevOps

## Addressing
| Term | Definition | Example |
|---|---|---|
| **IP address** | A 32-bit number (IPv4) identifying a network interface: `10.0.1.25`. IPv6 is 128-bit. | `ip -4 addr show` · `hostname -I` |
| **CIDR** | `address/prefix`: the prefix is how many leading bits are fixed (the network part). | `10.0.1.0/24` = `10.0.1.0` – `10.0.1.255` |
| **Block size** | 2^(32 − prefix): `/24` = 256 addresses, `/16` = 65,536, `/32` = one host, `/0` = everything. | `echo $(( 2 ** (32 - 24) ))` → `256` |
| **Subnetting** | Splitting a block into smaller, non-overlapping blocks. | `10.0.0.0/16` → `10.0.1.0/24`, `10.0.2.0/24`, … |
| **Private ranges (RFC 1918)** | `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` — not routed on the internet. | Home Wi-Fi `192.168.1.10`; a VPC `10.0.0.0/16` |
| **Public IP** | A globally unique, internet-routable address. | `curl -s https://checkip.amazonaws.com` |
| **NAT** | Rewriting addresses so many private hosts share a public one. | Every device at home leaves through the router's one public IP |
| **Route** | "To reach this block, send packets to that next hop." | `ip route` → `default via 172.20.0.1 dev eth0` |
| **Longest prefix match** | When several routes match, the most specific one wins. | `10.0.11.7` matches `/16 local` and `/0 IGW` → `/16` wins |
| **Default route** | `0.0.0.0/0`: where everything else goes. | `0.0.0.0/0 → igw-…` in a public route table |

## Transport
| Term | Definition | Example |
|---|---|---|
| **Port** | A number (0–65535) that identifies a program on a host. The IP finds the machine; the port finds the service. | `curl http://localhost:8080` |
| **Well-known ports** | 22 SSH, 53 DNS, 80 HTTP, 443 HTTPS, 3306 MySQL, 5432 PostgreSQL. | `grep -w 443 /etc/services` |
| **Ephemeral port** | The random high port (1024–65535) a client uses for its side of a connection. | `ss -tn` → `10.0.0.5:51234 → 93.184.215.14:443` |
| **Socket** | One end of a connection: IP + port. | `127.0.0.1:80` |
| **TCP** | Connection-based, reliable, ordered delivery; starts with the **3-way handshake** (SYN → SYN-ACK → ACK). | `nc -zv example.com 443` → `succeeded` |
| **UDP** | Connectionless, no delivery guarantee, low overhead (DNS, NTP, streaming). | `dig example.com` (DNS over UDP 53) |
| **Listening** | A server bound to a port, waiting. `0.0.0.0` = all interfaces; `127.0.0.1` = this machine only. | `python3 -m http.server 8000` · `ss -tlnp \| grep 8000` |
| **Connection refused** | Reached the host, but nothing listens on that port (a TCP reset). | `curl localhost:9` → `Connection refused` |
| **Timeout** | No answer at all: dropped by a firewall, no route, or host down. | `curl -m 5 http://10.255.255.1` → `timed out` |

## DNS
| Term | Definition | Example |
|---|---|---|
| **DNS** | The system that translates names into IP addresses. | `dig +short example.com` → `93.184.215.14` |
| **Resolver (recursive)** | The server that walks the hierarchy for you and caches answers. | `dig @8.8.8.8 example.com` (ask Google's resolver) |
| **Root → TLD → authoritative** | The lookup chain: root servers, then `.com` servers, then the domain's own servers. | `dig +trace example.com` |
| **Authoritative server** | The source of truth for a domain's records. | `dig NS example.com +short` |
| **TTL** | How long an answer may be cached (seconds). | `dig example.com` → `example.com. 300 IN A …` (300 s) |
| **A / AAAA** | Name → IPv4 / IPv6 address. | `dig A example.com +short` · `dig AAAA example.com +short` |
| **CNAME** | Name → another name (an alias). | `dig www.github.com +short` → `github.com.` |
| **MX / TXT / NS** | Mail servers / free text (verification, SPF) / the zone's name servers. | `dig MX gmail.com +short` · `dig TXT example.com +short` |
| **`/etc/hosts`** | Local name overrides, checked before DNS. | `echo "127.0.0.1 myapp.local" \| sudo tee -a /etc/hosts` |
| **`/etc/resolv.conf`** | Which resolver this machine uses. | `cat /etc/resolv.conf` → `nameserver 10.255.255.254` |

## HTTP and TLS
| Term | Definition | Example |
|---|---|---|
| **HTTP** | A request/response protocol over TCP: method + path + headers + body → status + headers + body. | `curl -v http://example.com` |
| **Methods** | GET read, POST create, PUT/PATCH update, DELETE remove. | `curl -X POST -d 'name=ali' https://httpbin.org/post` |
| **Status codes** | 2xx success, 3xx redirect, **4xx client error** (400, 401, 403, 404), **5xx server error** (500, 502, 503, 504). | `curl -s -o /dev/null -w '%{http_code}\n' https://example.com` → `200` |
| **Header** | Metadata on a request/response: `Host`, `Content-Type`, `Location`, `Cache-Control`. | `curl -I https://example.com` |
| **Redirect** | A 3xx response with a `Location` header pointing elsewhere. | `curl -I http://github.com` → `301`, `Location: https://github.com/` · follow with `curl -L` |
| **Proxy / reverse proxy** | A server in front of other servers that forwards requests (502/504 come from here). | nginx in front of an app on port 5000 |
| **HTTPS / TLS** | HTTP inside TLS: **encryption**, **integrity**, **authentication**. | `curl -v https://example.com` → `SSL connection using TLSv1.3` |
| **Certificate** | A server's public key + name, signed by a Certificate Authority. | `openssl s_client -connect example.com:443 -servername example.com </dev/null \| openssl x509 -noout -subject -dates` |
| **Certificate Authority (CA)** | A trusted issuer of certificates. | `… \| openssl x509 -noout -issuer` → `DigiCert …` |
| **Chain of trust** | Server cert ← intermediate CA ← root CA your system already trusts. | `openssl s_client -connect example.com:443 -showcerts` |
| **SNI** | The client names the site during the handshake, so one IP can serve many certificates. | `-servername example.com` in `openssl s_client` |

## Troubleshooting method
| Term | Definition | Example |
|---|---|---|
| **Layered troubleshooting** | Check bottom-up and stop at the first broken layer: name → route → port → service → response → certificate. | `dig` → `ping` → `nc -zv` → `curl -I` → `openssl s_client` |
| **ping / traceroute / mtr** | Is the host reachable / which hops does the path take / both, continuously. | `ping -c 4 8.8.8.8` · `traceroute example.com` · `mtr example.com` |
| **dig** | Queries DNS directly. | `dig +short example.com` |
| **ss** | Shows listening ports and connections on this machine. | `sudo ss -tulnp` |
| **curl** | Makes HTTP requests and shows headers, timing and errors. | `curl -w 'total=%{time_total}s\n' -o /dev/null -s https://example.com` |
| **tcpdump** | Captures packets on the wire. | `sudo tcpdump -i any port 80 -c 10` |

## AWS VPC
| Term | Definition | Example |
|---|---|---|
| **Region** | A geographic AWS location (`us-east-1`). | `aws configure get region` |
| **Availability Zone (AZ)** | An isolated data center within a region. | `us-east-1a`, `us-east-1b` |
| **VPC** | Your private, isolated network in one region, defined by a CIDR block. | `aws ec2 create-vpc --cidr-block 10.0.0.0/16` |
| **Subnet** | A slice of the VPC's CIDR that lives in exactly one AZ. | `aws ec2 create-subnet --vpc-id vpc-… --cidr-block 10.0.1.0/24 --availability-zone us-east-1a` |
| **Reserved IPs** | AWS keeps 5 per subnet: network, router (+1), DNS (+2), future (+3), broadcast. | `/24` → 256 − 5 = **251** usable |
| **Route table** | The routes a subnet uses; every subnet uses exactly one. | `aws ec2 create-route-table --vpc-id vpc-…` |
| **`local` route** | Automatic route covering the whole VPC — subnets can always reach each other (if firewalls allow). | `10.0.0.0/16 → local` |
| **Main route table** | The default table for subnets without an explicit association. | `aws ec2 describe-route-tables --filters Name=association.main,Values=true` |
| **Internet gateway (IGW)** | Connects the VPC to the internet and maps private ↔ public IPs. | `aws ec2 attach-internet-gateway --internet-gateway-id igw-… --vpc-id vpc-…` |
| **Public subnet** | A subnet whose route table has `0.0.0.0/0 → IGW`. Nothing else makes it public. | `aws ec2 create-route --route-table-id rtb-… --destination-cidr-block 0.0.0.0/0 --gateway-id igw-…` |
| **Private subnet** | A subnet with no route to the IGW. | Its route table shows only `10.0.0.0/16 → local` |
| **NAT gateway** | Lets private instances start connections **out** to the internet, never in. Lives in a public subnet; costs money. | `0.0.0.0/0 → nat-…` in the private route table (drawn, not built) |
| **Elastic IP** | A fixed public IPv4 you own (vs a temporary public IP that changes on stop). | `aws ec2 allocate-address` (billed — not used in the sprint) |
| **VPC endpoint** | A private path from the VPC to an AWS service without the internet. | A free S3 **gateway** endpoint for private subnets |

## Firewalls in AWS
| Term | Definition | Example |
|---|---|---|
| **Security group (SG)** | A firewall on an instance's network interface. **Allow rules only, stateful**, all rules evaluated. | `aws ec2 authorize-security-group-ingress --group-id sg-… --protocol tcp --port 80 --cidr 203.0.113.7/32` |
| **Network ACL (NACL)** | A firewall at the subnet boundary. **Allow and deny, stateless**, numbered rules, **first match wins**. | Rule `90 DENY 198.51.100.0/24`, rule `100 ALLOW 0.0.0.0/0` |
| **Stateful** | Remembers connections: replies to allowed traffic are allowed automatically. | SG allows inbound 80 → the reply goes out with no outbound rule |
| **Stateless** | Judges every packet alone: replies need their own rule (ephemeral ports). | NACL needs outbound `1024-65535` for HTTP replies |
| **Inbound / outbound** | Traffic coming in / going out. | Inbound: browser → nginx :80 · Outbound: `dnf` → repo :443 |
| **SG referencing** | A rule's source can be another security group: "allow from any instance in `web-sg`". | DB SG: allow `5432` from `sg-web` |
| **Defence in depth** | Several independent layers (no route + SG + NACL), so one mistake isn't enough. | Private DB: no internet route **and** an SG allowing only `sg-web` |

---

# Day 4 — Git and GitHub

## Core ideas
| Term | Definition | Example |
|---|---|---|
| **Version control** | Recording every change to files: who, when, why — with the ability to go back. | `git log --oneline` → the full history |
| **Distributed VCS** | Every clone holds the **full history**; most work is offline. | `git clone …` then `git log` with no internet |
| **Git** | The distributed version control program. | `git --version` |
| **GitHub** | A hosting service for Git repos, adding pull requests, reviews, issues and Actions. | `gh repo view --web` |
| **Repository (repo)** | A project's files plus its full history (the `.git` folder). | `git init my-project` · `ls -a` → `.git` |
| **Snapshot** | Git stores the full state of all files per commit (unchanged files are shared). | `git show --stat HEAD` |
| **Commit** | A snapshot + author + date + message + parent(s). | `git commit -m "docs: add Day 4 notes"` |
| **Hash (SHA)** | A commit's ID, computed from its content: change anything, the ID changes. | `git rev-parse --short HEAD` → `f05f0f5` |
| **Object** | What Git stores: **blob** (file content), **tree** (folder), **commit**, **tag**. | `git cat-file -t HEAD` → `commit` |

## The three areas and file states
| Term | Definition | Example |
|---|---|---|
| **Working tree** | The files you see and edit. | `echo hi >> notes.md` |
| **Staging area (index)** | A draft of the next commit; you choose what goes in. | `git add notes.md` · `git diff --staged` |
| **Repository** | The saved history. | `git commit -m "docs: update notes"` |
| **Untracked / tracked** | Unknown to Git / under version control. | `git status -s` → `?? new.txt` (untracked) |
| **Modified / staged** | Changed but not added / added and ready to commit. | `git status -s` → ` M a.md` (modified) · `M  a.md` (staged) |
| **`.gitignore`** | Patterns of files Git must never track (logs, build output, `.env`). | `echo "*.log" >> .gitignore` · `git check-ignore -v app.log` |
| **Configuration levels** | system → global (`~/.gitconfig`) → local (`.git/config`); the most specific wins. | `git config --global user.name "Wisam"` · `git config --show-origin user.email` |

## Branches and refs
| Term | Definition | Example |
|---|---|---|
| **Branch** | A movable pointer to a commit; moves forward with each new commit. | `git switch -c docs/day05` |
| **HEAD** | Where you are now — usually pointing at the current branch. | `cat .git/HEAD` → `ref: refs/heads/main` |
| **Detached HEAD** | HEAD points directly at a commit; new commits there can be lost. | `git switch --detach HEAD~1` · back: `git switch main` |
| **Ref** | Any name that points to a commit: branch, tag, `HEAD`. | `git show-ref --heads` |
| **Relative refs** | `HEAD^` parent, `HEAD~3` three back, `HEAD^2` second parent of a merge. | `git log --oneline -1 HEAD~2` |
| **Tag** | A fixed name for one commit (a release). **Annotated** tags store tagger, date and message. | `git tag -a v1.0 -m "First release"` · `git push origin v1.0` |
| **Topic (feature) branch** | A short-lived branch for one task, merged by PR and deleted. | `git switch -c fix/healthcheck-exit` |
| **Long-running branch** | A permanent branch at a stability level (`main`, `develop`). | `main`, `development` |
| **GitHub flow / Git flow** | `main` + short topic branches / `main` + `develop` + feature, release and hotfix branches. | `docs/day01` → PR → `git-lab` · `hotfix/…` → `development` |

## Combining work
| Term | Definition | Example |
|---|---|---|
| **Merge** | Combine another branch's commits into the current one. | `git switch main && git merge feature/login` |
| **Fast-forward** | The target didn't move, so the pointer just slides forward — no new commit. | `git merge feature/x` → `Fast-forward` |
| **3-way merge** | Both sides moved: Git combines them from their **common ancestor (base)** into a **merge commit** with two parents. | `git cat-file -p HEAD` → two `parent` lines |
| **Merge conflict** | Both sides changed the same lines; Git marks them and you decide. | `git diff --name-only --diff-filter=U` → `SPRINT.md` |
| **Ours / theirs** | In a merge: the branch you're on / the branch coming in. **Swapped during a rebase.** | `git checkout --theirs SPRINT.md` |
| **`-X ours` / `-X theirs`** | Auto-resolve only conflicting parts in favour of one side; other changes still merge. | `git merge -X theirs feature/configs` |
| **`-s ours`** | Ignore the other branch entirely (rarely what you want). | `git merge -s ours old-branch` |
| **Rebase** | Replay your commits on top of another branch, giving a straight history with **new** hashes. | `git switch feature/x && git rebase main` |
| **Golden rule of rebasing** | Never rebase commits others already pulled. | Pushed PR branch → `git merge origin/main` instead |
| **Squash** | Combine several commits into one. | `gh pr merge --squash` · `git reset --soft main && git commit` |
| **Cherry-pick / `rebase --onto`** | Copy chosen commits / move only part of a branch to a new base. | `git cherry-pick a1b2c3d` · `git rebase --onto main server client` |

## Remotes
| Term | Definition | Example |
|---|---|---|
| **Remote** | Another copy of the repo, usually on GitHub; the default name is `origin`. | `git remote -v` |
| **Clone** | Copy a remote repo with its full history. | `git clone https://github.com/<you>/repo.git` |
| **Fetch** | Download new commits without changing your files. | `git fetch --prune` |
| **Pull** | Fetch + merge (or rebase). | `git pull --rebase` |
| **Push** | Upload your commits; rejected if the remote has commits you don't have. | `git push -u origin docs/day05` |
| **Remote-tracking branch** | `origin/main`: your read-only bookmark of the remote branch at the last fetch. | `git log --oneline -3 origin/main` |
| **Upstream (tracking)** | The remote branch a local branch follows ("ahead 1, behind 2"). | `git branch -vv` → `[origin/main: ahead 1]` |
| **Force push / `--force-with-lease`** | Overwrite remote history / the same, but refuse if someone pushed meanwhile. | `git push --force-with-lease` |

## Collaboration on GitHub
| Term | Definition | Example |
|---|---|---|
| **Pull request (PR)** | A request to merge one branch into another, with discussion, review and checks. | `gh pr create --base git-lab --fill` |
| **Code review** | Reading a diff and approving or requesting changes before merge. | `gh pr diff 7` · `gh pr review 7 --approve` (a teammate's PR) |
| **Self-review** | Checking your own diff first: right files, no secrets, clear title. | `git diff --stat origin/main...HEAD` · `gh pr review --comment -b "Self-review: …"` |
| **Merge strategies** | Merge commit, squash and merge, rebase and merge. | `gh pr merge --squash --delete-branch` |
| **Branch protection** | Server-side rules on a branch: no direct pushes, PR required, checks must pass, apply to admins. | Direct push → `GH006: Protected branch update failed` |
| **CODEOWNERS** | A file that auto-assigns reviewers by path. | `.github/CODEOWNERS` → `infra/ @devops-team` |
| **Fork** | Your own copy of someone else's repo. | `gh repo fork owner/project --clone` |
| **Conventional Commits** | Message format `type: summary` — `feat`, `fix`, `docs`, `chore`, `refactor`. | `fix: exit 1 when the URL check fails` |
| **Git hook** | A script Git runs at certain moments (e.g. `pre-push`); a local guard rail. | `.git/hooks/pre-push` that blocks pushes to `main` |

## Undoing and safety
| Term | Definition | Example |
|---|---|---|
| **restore** | Discard uncommitted changes, or unstage a file. | `git restore notes.md` · `git restore --staged notes.md` |
| **amend** | Rewrite the last commit (only before pushing). | `git commit --amend -m "docs: better message"` |
| **reset** | Move the branch back: `--soft` keeps changes staged, `--mixed` unstaged, `--hard` deletes them. | `git reset --soft HEAD~1` · `git reset --hard origin/main` |
| **revert** | A new commit that undoes an old one — the safe undo for pushed work. | `git revert a1b2c3d` |
| **reflog** | A log of everywhere HEAD has been — recovers "lost" commits. | `git reflog` · `git reset --hard 'HEAD@{1}'` |
| **stash** | Temporarily shelve uncommitted work. | `git stash` · `git stash pop` |
| **Secret in history** | Deleting a committed secret doesn't remove it from history — **rotate** it. | `git log -p -S "API_KEY"` finds it in old commits |
