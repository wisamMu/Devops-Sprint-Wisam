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
| Term | Definition |
|---|---|
| **Bash** | The "Bourne Again SHell": an interactive shell and a scripting language. |
| **Script** | A text file of commands run in order. |
| **Shebang** | First line `#!/usr/bin/env bash`: tells the OS which interpreter runs the file. |
| **Executable bit** | `chmod +x` lets a script be run as `./script.sh`. |
| **PATH** | The list of folders the shell searches for commands. |
| **Environment variable** | A variable passed down to child processes (`export NAME=value`). |

## Streams and redirection
| Term | Definition |
|---|---|
| **stdin / stdout / stderr** | Standard input (0), output (1) and error (2) — the three streams every process has. |
| **Pipe `\|`** | Sends one command's stdout into the next command's stdin. |
| **`>` / `>>`** | Write stdout to a file (overwrite / append). |
| **`2>` / `2>&1`** | Redirect stderr / merge stderr into stdout. |
| **`/dev/null`** | A "black hole" that discards whatever is written to it. |
| **Here-document `<<EOF`** | Feeds several lines as input to a command. Quoted `'EOF'` stops variable expansion. |
| **tee** | Writes input to the screen **and** a file at once. |

## Text tools
| Term | Definition |
|---|---|
| **grep** | Prints lines that match a pattern. |
| **sed** | Stream editor: substitutes, deletes or inserts text line by line. |
| **awk** | Splits each line into fields (`$1`, `$2`…) and runs small programs on them. |
| **Regular expression (regex)** | A pattern language: `^` start, `$` end, `.` any char, `*` repeat, `[0-9]` a class, `\|` or (in `-E` extended mode). |
| **cut / sort / uniq / wc** | Pick columns / sort lines / collapse duplicates / count lines, words, bytes. |

## Variables and expansion
| Term | Definition |
|---|---|
| **Variable** | `name=value` (no spaces around `=`); read with `"$name"`. |
| **Quoting** | Double quotes keep spaces together but expand `$vars`; single quotes keep everything literal. Unquoted variables split on spaces — a common bug. |
| **Command substitution** | `$(command)` is replaced by the command's output. |
| **Arithmetic expansion** | `$(( a + b ))` does integer math. |
| **Parameter expansion** | `${x:-default}` (use a default), `${x#prefix}` (strip a prefix), `${#x}` (length). |
| **Positional parameters** | `$1`, `$2`… the script's arguments; `$@` all of them; `$#` how many. |
| **local** | A variable that exists only inside a function. |

## Control flow
| Term | Definition |
|---|---|
| **Exit code** | A number every command returns: **0 = success**, anything else = failure. `$?` holds the last one. |
| **`&&` / `\|\|`** | Run the next command only if the previous one succeeded / failed. |
| **`if` / `[[ … ]]`** | Branch on a test: strings, files (`-f`, `-d`), regex (`=~`). |
| **`(( … ))`** | Numeric comparison and math (`(( x > 80 ))`). |
| **case** | Branch on a value matching patterns — tidy for command-line options. |
| **for / while** | Loop over a list / loop while a condition is true (`while read line`). |
| **Function** | A named, reusable block of commands. |

## Robust scripts
| Term | Definition |
|---|---|
| **`set -e`** | Stop the script when a command fails. |
| **`set -u`** | Treat an unset variable as an error. |
| **`set -o pipefail`** | A pipeline fails if **any** command in it fails, not just the last. |
| **Strict mode** | `set -euo pipefail` together. Trap: `(( x++ ))` returns 1 when x was 0, which stops the script. |
| **trap** | Runs a command when the script exits or receives a signal (cleanup). |
| **Idempotent** | Running it twice gives the same result as once — a goal for automation. |
| **Linter (ShellCheck)** | A tool that finds bugs and bad patterns without running the script. |
| **Health check** | A script that tests a system (disk, memory, URL, service) and reports through its exit code. |

---

# Day 3 — Networking for DevOps

## Addressing
| Term | Definition |
|---|---|
| **IP address** | A 32-bit number (IPv4) identifying a network interface: `10.0.1.25`. IPv6 is 128-bit. |
| **CIDR** | `address/prefix`: the prefix is how many leading bits are fixed (the network part). |
| **Block size** | 2^(32 − prefix): `/24` = 256 addresses, `/16` = 65,536, `/32` = one host, `/0` = everything. |
| **Subnetting** | Splitting a block into smaller, non-overlapping blocks. |
| **Private ranges (RFC 1918)** | `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` — not routed on the internet. |
| **Public IP** | A globally unique, internet-routable address. |
| **NAT** | Rewriting addresses so many private hosts share a public one. |
| **Route** | "To reach this block, send packets to that next hop." |
| **Longest prefix match** | When several routes match, the most specific one wins. |
| **Default route** | `0.0.0.0/0`: where everything else goes. |

## Transport
| Term | Definition |
|---|---|
| **Port** | A number (0–65535) that identifies a program on a host. The IP finds the machine; the port finds the service. |
| **Well-known ports** | 22 SSH, 53 DNS, 80 HTTP, 443 HTTPS, 3306 MySQL, 5432 PostgreSQL. |
| **Ephemeral port** | The random high port (1024–65535) a client uses for its side of a connection. |
| **Socket** | One end of a connection: IP + port. |
| **TCP** | Connection-based, reliable, ordered delivery; starts with the **3-way handshake** (SYN → SYN-ACK → ACK). |
| **UDP** | Connectionless, no delivery guarantee, low overhead (DNS, NTP, streaming). |
| **Listening** | A server bound to a port, waiting. `0.0.0.0` = all interfaces; `127.0.0.1` = this machine only. |
| **Connection refused** | Reached the host, but nothing listens on that port (a TCP reset). |
| **Timeout** | No answer at all: dropped by a firewall, no route, or host down. |

## DNS
| Term | Definition |
|---|---|
| **DNS** | The system that translates names into IP addresses. |
| **Resolver (recursive)** | The server that walks the hierarchy for you and caches answers. |
| **Root → TLD → authoritative** | The lookup chain: root servers, then `.com` servers, then the domain's own servers. |
| **Authoritative server** | The source of truth for a domain's records. |
| **TTL** | How long an answer may be cached (seconds). |
| **A / AAAA** | Name → IPv4 / IPv6 address. |
| **CNAME** | Name → another name (an alias). |
| **MX / TXT / NS** | Mail servers / free text (verification, SPF) / the zone's name servers. |
| **`/etc/hosts`** | Local name overrides, checked before DNS. |
| **`/etc/resolv.conf`** | Which resolver this machine uses. |

## HTTP and TLS
| Term | Definition |
|---|---|
| **HTTP** | A request/response protocol over TCP: method + path + headers + body → status + headers + body. |
| **Methods** | GET read, POST create, PUT/PATCH update, DELETE remove. |
| **Status codes** | 2xx success, 3xx redirect, **4xx client error** (400, 401, 403, 404), **5xx server error** (500, 502 bad gateway, 503 unavailable, 504 gateway timeout). |
| **Header** | Metadata on a request/response: `Host`, `Content-Type`, `Location`, `Cache-Control`. |
| **Redirect** | A 3xx response with a `Location` header pointing elsewhere. |
| **Proxy / reverse proxy** | A server in front of other servers that forwards requests (502/504 come from here). |
| **HTTPS / TLS** | HTTP inside TLS: **encryption**, **integrity**, **authentication**. |
| **Certificate** | A server's public key + name, signed by a Certificate Authority. |
| **Certificate Authority (CA)** | A trusted issuer of certificates. |
| **Chain of trust** | Server cert ← intermediate CA ← root CA your system already trusts. |
| **SNI** | The client names the site during the handshake, so one IP can serve many certificates. |

## Troubleshooting method
| Term | Definition |
|---|---|
| **Layered troubleshooting** | Check bottom-up and stop at the first broken layer: name → route → port → service → response → certificate. |
| **ping / traceroute / mtr** | Is the host reachable / which hops does the path take / both, continuously. |
| **dig** | Queries DNS directly. |
| **ss** | Shows listening ports and connections on this machine. |
| **curl** | Makes HTTP requests and shows headers, timing and errors. |
| **tcpdump** | Captures packets on the wire. |

## AWS VPC
| Term | Definition |
|---|---|
| **Region** | A geographic AWS location (`us-east-1`). |
| **Availability Zone (AZ)** | An isolated data center within a region. |
| **VPC** | Your private, isolated network in one region, defined by a CIDR block. |
| **Subnet** | A slice of the VPC's CIDR that lives in exactly one AZ. |
| **Reserved IPs** | AWS keeps 5 per subnet: network, router (+1), DNS (+2), future (+3), broadcast. |
| **Route table** | The routes a subnet uses; every subnet uses exactly one. |
| **`local` route** | Automatic route covering the whole VPC — subnets can always reach each other (if firewalls allow). |
| **Main route table** | The default table for subnets without an explicit association. |
| **Internet gateway (IGW)** | Connects the VPC to the internet and maps private ↔ public IPs. |
| **Public subnet** | A subnet whose route table has `0.0.0.0/0 → IGW`. Nothing else makes it public. |
| **Private subnet** | A subnet with no route to the IGW. |
| **NAT gateway** | Lets private instances start connections **out** to the internet, never in. Lives in a public subnet; costs money. |
| **Elastic IP** | A fixed public IPv4 you own (vs a temporary public IP that changes on stop). |
| **VPC endpoint** | A private path from the VPC to an AWS service without the internet. |

## Firewalls in AWS
| Term | Definition |
|---|---|
| **Security group (SG)** | A firewall on an instance's network interface. **Allow rules only, stateful**, all rules evaluated. |
| **Network ACL (NACL)** | A firewall at the subnet boundary. **Allow and deny, stateless**, numbered rules, **first match wins**. |
| **Stateful** | Remembers connections: replies to allowed traffic are allowed automatically. |
| **Stateless** | Judges every packet alone: replies need their own rule (ephemeral ports). |
| **Inbound / outbound** | Traffic coming in / going out. |
| **SG referencing** | A rule's source can be another security group: "allow from any instance in `web-sg`". |
| **Defence in depth** | Several independent layers (no route + SG + NACL), so one mistake isn't enough. |

---

# Day 4 — Git and GitHub

## Core ideas
| Term | Definition |
|---|---|
| **Version control** | Recording every change to files: who, when, why — with the ability to go back. |
| **Distributed VCS** | Every clone holds the **full history**; most work is offline. |
| **Git** | The distributed version control program. |
| **GitHub** | A hosting service for Git repos, adding pull requests, reviews, issues and Actions. |
| **Repository (repo)** | A project's files plus its full history (the `.git` folder). |
| **Snapshot** | Git stores the full state of all files per commit (unchanged files are shared). |
| **Commit** | A snapshot + author + date + message + parent(s). |
| **Hash (SHA)** | A commit's ID, computed from its content: change anything, the ID changes. |
| **Object** | What Git stores: **blob** (file content), **tree** (folder), **commit**, **tag**. |

## The three areas and file states
| Term | Definition |
|---|---|
| **Working tree** | The files you see and edit. |
| **Staging area (index)** | A draft of the next commit; you choose what goes in. |
| **Repository** | The saved history. |
| **Untracked / tracked** | Unknown to Git / under version control. |
| **Modified / staged** | Changed but not added / added and ready to commit. |
| **`.gitignore`** | Patterns of files Git must never track (logs, build output, `.env`). |
| **Configuration levels** | system → global (`~/.gitconfig`) → local (`.git/config`); the most specific wins. |

## Branches and refs
| Term | Definition |
|---|---|
| **Branch** | A movable pointer to a commit; moves forward with each new commit. |
| **HEAD** | Where you are now — usually pointing at the current branch. |
| **Detached HEAD** | HEAD points directly at a commit; new commits there can be lost. |
| **Ref** | Any name that points to a commit: branch, tag, `HEAD`. |
| **Relative refs** | `HEAD^` parent, `HEAD~3` three back, `HEAD^2` second parent of a merge. |
| **Tag** | A fixed name for one commit (a release). **Annotated** tags store tagger, date and message. |
| **Topic (feature) branch** | A short-lived branch for one task, merged by PR and deleted. |
| **Long-running branch** | A permanent branch at a stability level (`main`, `develop`). |
| **GitHub flow / Git flow** | `main` + short topic branches / `main` + `develop` + feature, release and hotfix branches. |

## Combining work
| Term | Definition |
|---|---|
| **Merge** | Combine another branch's commits into the current one. |
| **Fast-forward** | The target didn't move, so the pointer just slides forward — no new commit. |
| **3-way merge** | Both sides moved: Git combines them from their **common ancestor (base)** into a **merge commit** with two parents. |
| **Merge conflict** | Both sides changed the same lines; Git marks them and you decide. |
| **Ours / theirs** | In a merge: the branch you're on / the branch coming in. **Swapped during a rebase.** |
| **`-X ours` / `-X theirs`** | Auto-resolve only conflicting parts in favour of one side; other changes still merge. |
| **`-s ours`** | Ignore the other branch entirely (rarely what you want). |
| **Rebase** | Replay your commits on top of another branch, giving a straight history with **new** hashes. |
| **Golden rule of rebasing** | Never rebase commits others already pulled. |
| **Squash** | Combine several commits into one. |
| **Cherry-pick / `rebase --onto`** | Copy chosen commits / move only part of a branch to a new base. |

## Remotes
| Term | Definition |
|---|---|
| **Remote** | Another copy of the repo, usually on GitHub; the default name is `origin`. |
| **Clone** | Copy a remote repo with its full history. |
| **Fetch** | Download new commits without changing your files. |
| **Pull** | Fetch + merge (or rebase). |
| **Push** | Upload your commits; rejected if the remote has commits you don't have. |
| **Remote-tracking branch** | `origin/main`: your read-only bookmark of the remote branch at the last fetch. |
| **Upstream (tracking)** | The remote branch a local branch follows ("ahead 1, behind 2"). |
| **Force push / `--force-with-lease`** | Overwrite remote history / the same, but refuse if someone pushed meanwhile. |

## Collaboration on GitHub
| Term | Definition |
|---|---|
| **Pull request (PR)** | A request to merge one branch into another, with discussion, review and checks. |
| **Code review** | Reading a diff and approving or requesting changes before merge. |
| **Self-review** | Checking your own diff first: right files, no secrets, clear title. |
| **Merge strategies** | Merge commit, squash and merge, rebase and merge. |
| **Branch protection** | Server-side rules on a branch: no direct pushes, PR required, checks must pass, apply to admins. |
| **CODEOWNERS** | A file that auto-assigns reviewers by path. |
| **Fork** | Your own copy of someone else's repo. |
| **Conventional Commits** | Message format `type: summary` — `feat`, `fix`, `docs`, `chore`, `refactor`. |
| **Git hook** | A script Git runs at certain moments (e.g. `pre-push`); a local guard rail. |

## Undoing and safety
| Term | Definition |
|---|---|
| **restore** | Discard uncommitted changes, or unstage a file. |
| **amend** | Rewrite the last commit (only before pushing). |
| **reset** | Move the branch back: `--soft` keeps changes staged, `--mixed` unstaged, `--hard` deletes them. |
| **revert** | A new commit that undoes an old one — the safe undo for pushed work. |
| **reflog** | A log of everywhere HEAD has been — recovers "lost" commits. |
| **stash** | Temporarily shelve uncommitted work. |
| **Secret in history** | Deleting a committed secret doesn't remove it from history — **rotate** it. |
