# Day 1 — Linux Essentials

**Date:** 2026-11-04
**Topic:** Linux essentials — filesystem, users, permissions, processes, systemd, packages
**Where:** WSL Ubuntu 24.04 (learning) → Amazon Linux 2023 on EC2 (lab)
**Goal:** Run and troubleshoot a Linux server: find my way around, manage users and permissions, control processes, install and debug a service.
**Cost:** ~$0.05 of AWS Free plan credits (the EC2 ran about 1 hour). $0 paid.

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

# Part 1 — Learning in WSL

All practice ran locally in WSL Ubuntu, in `~/practice`, so it cost nothing and nothing important could break.

> In every table below, `&&` means "run the next command only if the previous one succeeded".

## Section 1 — Command Line

**Read:** Linux Journey → Command Line (The Shell, pwd, cd, ls, touch, file, cat, less, history, cp, mv, mkdir, rm, find, help, man, whatis, alias, exit).

### 1.1 Where am I, and what's here?

```bash
pwd
ls -la ~
```

| Part | Meaning |
|---|---|
| `pwd` | **P**rint **w**orking **d**irectory — the folder I'm in (`/home/wmusleh`) |
| `ls` | List files |
| `-l` | Long format: permissions, owner, group, size, date |
| `-a` | **A**ll files, including hidden ones (names starting with `.`, like `.aws`, `.gitconfig`) |
| `~` | My home folder |

### 1.2 Make a practice playground

```bash
mkdir -p ~/practice/day1/{logs,configs,scripts}
cd ~/practice/day1 && ls
```

| Part | Meaning |
|---|---|
| `mkdir` | **M**a**k**e **dir**ectory |
| `-p` | Create parent folders if missing; no error if it already exists |
| `{logs,configs,scripts}` | **Brace expansion** — Bash turns it into 3 names, so one command makes 3 folders |
| `cd` | **C**hange **d**irectory |

### 1.3 Create and inspect files

```bash
touch notes.txt configs/app.conf logs/app.log
echo "server=nginx" > configs/app.conf && cat configs/app.conf
file configs/app.conf /bin/ls
```

| Part | Meaning |
|---|---|
| `touch` | Create empty files (or update the timestamp of existing ones) |
| `echo "..." > file` | Write text into a file; `>` creates or **overwrites** |
| `cat` | Print a file's contents |
| `file` | Say what kind of file it is — text, or an "ELF executable" program like `/bin/ls` |

### 1.4 Copy, move, rename

```bash
cp configs/app.conf configs/app.conf.bak
mv notes.txt scripts/ && mv scripts/notes.txt scripts/readme.txt
ls -R
```

| Part | Meaning |
|---|---|
| `cp SRC DST` | Copy — making a `.bak` before editing a real config is a good habit |
| `mv SRC DST` | **Move**, and also **rename** — Linux has no separate rename command |
| `ls -R` | List **R**ecursively — all subfolders |

### 1.5 Find files

```bash
find ~/practice -name "*.conf*"
find ~/practice -type d
```

| Part | Meaning |
|---|---|
| `find PATH` | Search PATH and every folder under it |
| `-name "*.conf*"` | Match names; `*` = any characters; quotes stop the shell expanding `*` itself |
| `-type d` | Only **d**irectories (`-type f` = only files) |

### 1.6 Get help without Google

```bash
whatis ls cp mv
man ls
```

| Part | Meaning |
|---|---|
| `whatis` | One-line description of each command |
| `man` | Full **man**ual. Inside: `/text` search, `n` next match, `q` quit |

### 1.7 Delete safely

```bash
rm configs/app.conf.bak && ls configs
rm -ri ~/practice/day1/logs
```

| Part | Meaning |
|---|---|
| `rm` | Remove a file — **permanent**, there is no recycle bin |
| `-r` | **R**ecursive — delete a folder and everything inside |
| `-i` | **I**nteractive — ask before each deletion |
| `-f` (not used) | **F**orce — never ask. `rm -rf` with a typo can wipe a system |

### 1.8 History and aliases

```bash
history | tail -15
alias ll='ls -la' && ll
```

| Part | Meaning |
|---|---|
| `history` | Commands I've typed; `!!` re-runs the last one; `Ctrl+R` searches |
| `\| tail -15` | Show only the last 15 |
| `alias ll='ls -la'` | Shortcut for this session only (permanent ones go in `~/.bashrc`) |

### Quiz answers

| Question | Answer |
|---|---|
| `cd ~` vs `cd /` | My home folder vs the root of the whole filesystem |
| `cd ..` / `cd -` | Up one folder / back to the previous folder |
| Rename `app.log` to `old.log` | `mv app.log old.log` |
| Why is `rm -rf` dangerous? | Recursive, never asks, no recycle bin |

---

## Section 2 — Text-Fu

**Read:** Linux Journey → Text-Fu (stdout, stdin, stderr, pipe and tee, env, cut, head, tail, sort, tr, uniq, wc and nl, grep, Regular Expressions).

**Why it matters:** most troubleshooting is searching and filtering logs.

### 2.1 Create a sample web-server log

```bash
mkdir -p ~/practice/day1/logs && cd ~/practice/day1/logs && cat > access.log <<'EOF'
10.0.0.5 GET /index.html 200 0.12
10.0.0.7 GET /api/items 200 0.30
10.0.0.5 POST /api/items 201 0.45
10.0.0.9 GET /admin 403 0.02
10.0.0.7 GET /api/items 500 1.90
10.0.0.5 GET /health 200 0.01
10.0.0.8 GET /missing 404 0.03
10.0.0.7 GET /api/items 500 2.10
10.0.0.9 GET /admin 403 0.02
10.0.0.5 GET /health 200 0.01
EOF
```

| Part | Meaning |
|---|---|
| `cat > access.log <<'EOF' ... EOF` | A **heredoc**: everything up to the `EOF` line is written into the file |
| `'EOF'` in quotes | Stop Bash from interpreting `$` and other special characters inside |
| Columns | IP, method, path, status code, response time (seconds) |

### 2.2 Look at a file

```bash
wc -l access.log
head -3 access.log && tail -2 access.log
nl access.log | tail -3
```

| Part | Meaning |
|---|---|
| `wc -l` | **W**ord **c**ount, but `-l` counts **l**ines (`-w` words, `-c` bytes) |
| `head -3` | First 3 lines |
| `tail -2` | Last 2 lines |
| `nl` | **N**umber the **l**ines |
| `less file` | Scroll through a long file (`q` to quit) |

### 2.3 Search with grep

```bash
grep "500" access.log
grep -c " 500 " access.log
grep -v "/health" access.log
grep -E " (403|404|500) " access.log
```

| Part | Meaning |
|---|---|
| `grep "500"` | Show lines containing "500" |
| `-c` | **C**ount matching lines |
| `-v` | In**v**ert — lines that **don't** match (hide health-check noise) |
| `-E` | **E**xtended regex — `(403\|404\|500)` means "any of these" |
| `-i` | Case-**i**nsensitive |
| `" 500 "` with spaces | Precise match — without spaces, `500` would also match `0.500` |

### 2.4 Cut columns

```bash
cut -d' ' -f1 access.log
cut -d' ' -f3,4 access.log
```

| Part | Meaning |
|---|---|
| `-d' '` | **D**elimiter (column separator) is a space |
| `-f1` | **F**ield (column) 1 — the IP |
| `-f3,4` | Fields 3 and 4 — path and status |

### 2.5 Sort and count — the classic log pipeline

```bash
cut -d' ' -f1 access.log | sort | uniq -c | sort -rn
cut -d' ' -f4 access.log | sort | uniq -c | sort -rn
```

| Step | Output |
|---|---|
| `cut -d' ' -f1` | Just the IPs, one per line |
| `\| sort` | Sorted, so identical lines sit together |
| `\| uniq -c` | Collapse duplicates and **c**ount them — `uniq` only merges **adjacent** lines, hence `sort` first |
| `\| sort -rn` | **N**umeric sort, **r**everse — busiest first |
| Second line | Same, for status codes |

### 2.6 Transform with tr

```bash
cut -d' ' -f2 access.log | tr 'a-z' 'A-Z' | head -3
echo "a,b,c" | tr ',' '\n'
```

| Part | Meaning |
|---|---|
| `tr 'a-z' 'A-Z'` | **Tr**anslate lowercase to uppercase |
| `tr ',' '\n'` | Replace commas with new lines |

### 2.7 stdout, stderr and redirects

```bash
ls access.log nofile.txt
ls access.log nofile.txt > out.txt 2> err.txt; cat out.txt; cat err.txt
ls access.log nofile.txt > all.txt 2>&1; cat all.txt
```

| Symbol | Meaning |
|---|---|
| stdout (1) | Normal output |
| stderr (2) | Error messages |
| `>` | Send stdout to a file, overwrite |
| `>>` | Same, **append** |
| `2>` | Send stderr to a file |
| `2>&1` | Send stderr to wherever stdout goes — both in one file |
| `2>/dev/null` | Throw errors away (`/dev/null` is a "black hole") |
| `;` | Run the next command **regardless** of success |

### 2.8 Save and view at once with tee

```bash
grep " 500 " access.log | tee errors.txt | wc -l
```

| Part | Meaning |
|---|---|
| `tee errors.txt` | Write input to `errors.txt` **and** pass it on, like a T-junction |
| `\| wc -l` | Count what passed through |

### 2.9 Follow a live log

```bash
tail -f ~/practice/day1/logs/access.log                      # tab 2
echo "10.0.0.6 GET /live 200 0.05" >> access.log              # tab 1
```

| Part | Meaning |
|---|---|
| `tail -f` | **F**ollow — print new lines as they're added; `Ctrl+C` to stop |
| `>>` | Append a line; it appears instantly in the other tab |

### 2.10 Environment variables

```bash
echo $HOME $USER $SHELL
env | grep -i aws
```

| Part | Meaning |
|---|---|
| `$HOME`, `$USER`, `$SHELL` | Variables every program can read |
| `env` | List all environment variables |

### Challenge answers

```bash
grep -cE " [45][0-9]{2} " access.log                                      # 1. number of 4xx/5xx errors
grep " 500 " access.log | cut -d' ' -f3 | sort | uniq -c | sort -rn | head -1   # 2. path with most 500s
awk '$5 > 1' access.log                                                     # 3. requests slower than 1 s
grep -E " [45][0-9]{2} " access.log | tee errors.log | wc -l                # 4. save errors and count them
```

| Part | Meaning |
|---|---|
| `[45][0-9]{2}` | A 4 or 5, followed by exactly 2 digits — any 4xx/5xx status |
| `awk '$5 > 1'` | Print lines where column 5 (time) is greater than 1 |

---

## Section 3 — User Management

**Read:** Linux Journey → User Management (Users and Groups, root, /etc/passwd, /etc/shadow, /etc/group, User Management Tools).

**Why it matters:** every service should run as its **own non-root user** — if it's hacked, the attacker only gets that user's limited access.

### 3.1 Who am I?

```bash
whoami && id
```

| Part | Meaning |
|---|---|
| `whoami` | My username |
| `id` | My **uid**, main group **gid**, and all groups (`sudo` among them — that's why I can use sudo) |

### 3.2 Where users and groups live

```bash
tail -3 /etc/passwd
grep wmusleh /etc/passwd
```

```text
wmusleh:x:1000:1000:,,,:/home/wmusleh:/bin/bash
   │    │   │    │    │       │           └─ 7. login shell
   │    │   │    │    │       └───────────── 6. home folder
   │    │   │    │    └───────────────────── 5. comment (full name)
   │    │   │    └────────────────────────── 4. main group ID (GID)
   │    │   └─────────────────────────────── 3. user ID (UID)
   │    └─────────────────────────────────── 2. "x" = password is in /etc/shadow
   └──────────────────────────────────────── 1. username
```

- UID **0** = root. UID **1000+** = real people. Below 1000 = system/service users.

```bash
awk -F: '$3 < 1000 {print $1, $3, $7}' /etc/passwd | head
```

| Part | Meaning |
|---|---|
| `awk -F:` | Split each line on `:` |
| `$3 < 1000` | Keep system users |
| `{print $1, $3, $7}` | Print name, UID, shell — many are `/usr/sbin/nologin` |

```bash
sudo tail -3 /etc/shadow
ls -l /etc/passwd /etc/shadow
grep -E "^(sudo|wmusleh):" /etc/group
```

| Part | Meaning |
|---|---|
| `/etc/shadow` | **Hashed** passwords — readable only by root (`-rw-r-----`) |
| `/etc/passwd` | Readable by everyone (`-rw-r--r--`) — that's why passwords moved out of it |
| `/etc/group` | Format `name:x:GID:members`; `^` = start of line |

### 3.3 Create users and a group

```bash
sudo groupadd devops
sudo useradd -m -s /bin/bash -G devops alice
sudo useradd -m -s /bin/bash bob
sudo useradd -r -s /usr/sbin/nologin webapp
id alice && id bob && id webapp && getent group devops
```

| Part | Meaning |
|---|---|
| `groupadd devops` | Create a group (added to `/etc/group`) |
| `useradd alice` | Create a user (added to `/etc/passwd`) |
| `-m` | **M**ake a home folder `/home/alice` |
| `-s /bin/bash` | Login **s**hell |
| `-G devops` | Supplementary **G**roup |
| `-r` | **System** user — UID below 1000, no home folder |
| `-s /usr/sbin/nologin` | Nobody can log in as it; programs can still run as it |
| `getent group devops` | Look up the group and its members |

### 3.4 Modify a user — the `-a` trap

```bash
sudo usermod -aG devops bob && id bob
```

| Part | Meaning |
|---|---|
| `usermod` | Modify an existing user |
| `-a` | **A**ppend — keep existing groups |
| `-G devops` | Group to add |
| ⚠️ Without `-a` | `-G` **replaces** all supplementary groups — on my own user it would remove `sudo` |

### 3.5 Switch user

```bash
sudo passwd alice
su - alice
whoami && pwd && sudo ls /root      # as alice: sudo fails — not in sudoers
exit
sudo -iu alice whoami
sudo su - webapp                    # "This account is currently not available"
```

| Part | Meaning |
|---|---|
| `passwd alice` | Set alice's password (stored hashed in `/etc/shadow`) |
| `su - alice` | **S**witch **u**ser; `-` loads her full login environment |
| `sudo -iu alice` | Become alice using **my** sudo rights, no password needed; `-i` = login shell |
| `sudo su - webapp` | Blocked by `nologin` — the point of service users |

### 3.6 Who can use sudo?

```bash
getent group sudo
sudo cat /etc/sudoers | grep -v "^#" | grep -v "^$"
```

| Part | Meaning |
|---|---|
| `getent group sudo` | Members of the `sudo` group |
| `grep -v "^#"` / `grep -v "^$"` | Hide comment lines / empty lines |
| `%sudo ALL=(ALL:ALL) ALL` | Anyone in group `sudo` (`%` = group) can run anything as anyone |
| `sudo visudo` | **The only safe way** to edit sudoers — it checks syntax before saving |

On Amazon Linux the admin group is **`wheel`** instead of `sudo`.

### 3.7 Clean up

```bash
sudo userdel -r alice && sudo userdel -r bob && sudo userdel webapp && sudo groupdel devops
getent passwd alice bob webapp; getent group devops
```

| Part | Meaning |
|---|---|
| `userdel -r` | Delete the user **and** their home folder |
| `groupdel` | Delete the group |
| `getent ...` | No output = everything removed |

### Quiz answers

| Question | Answer |
|---|---|
| Root's UID | 0 |
| Why `x` in `/etc/passwd`? | The hash lives in root-only `/etc/shadow` |
| `useradd -G` vs `usermod -aG` | Set groups at creation vs add a group to an existing user |
| Why `nologin` for a web app? | An attacker can't get a shell as that user |
| Why `visudo`? | Syntax check — a broken sudoers file locks everyone out of sudo |

---

## Section 4 — Permissions

**Read:** Linux Journey → Permissions (File Permissions, Modifying Permissions, Ownership Permissions, Umask, Setuid, Setgid, Process Permissions, The Sticky Bit).

### 4.1 Reading permissions

```text
-rw-r--r-- 1 wmusleh wmusleh 0 Nov  4 10:00 file.txt
│└┬┘└┬┘└┬┘   └──┬──┘ └──┬──┘
│ │  │  │      owner   group
│ │  │  └─ others
│ │  └──── group
│ └─────── owner (user)
└───────── type: - file, d directory, l link
```

| | On a **file** | On a **folder** |
|---|---|---|
| `r` (4) | Read contents | **List** files (`ls`) |
| `w` (2) | Change contents | **Create, delete, rename** files inside |
| `x` (1) | **Run** it | **Enter** it (`cd`) and reach files inside |

| Octal | Symbolic | Typical use |
|---|---|---|
| `755` | `rwxr-xr-x` | Scripts, programs, public folders |
| `644` | `rw-r--r--` | Normal files, web pages |
| `640` | `rw-r-----` | Config readable by the app's group |
| `600` | `rw-------` | Secrets, SSH private keys |
| `700` | `rwx------` | Private folder |

### 4.2 Change permissions with chmod

```bash
mkdir -p ~/practice/perms && cd ~/practice/perms && touch file.txt && mkdir folder && ls -l
echo 'echo "Hello from a script"' > hello.sh && ./hello.sh       # Permission denied
chmod +x hello.sh && ls -l hello.sh && ./hello.sh
```

| Part | Meaning |
|---|---|
| `./hello.sh` | Run the file in the current folder |
| `chmod +x` | **Ch**ange **mod**e — add e**x**ecute for everyone |

```bash
chmod u=rwx,g=rx,o= hello.sh && ls -l hello.sh
chmod o+r hello.sh && ls -l hello.sh
chmod g-x hello.sh && ls -l hello.sh
chmod 600 file.txt && ls -l file.txt
chmod 755 hello.sh && ls -l hello.sh
```

| Part | Meaning |
|---|---|
| `u` / `g` / `o` / `a` | **u**ser (owner) / **g**roup / **o**thers / **a**ll |
| `+` / `-` / `=` | Add / remove / set exactly |
| `600`, `755` | Octal form — sets all three groups at once |

### 4.3 Folder permissions

```bash
echo "inside" > folder/a.txt && chmod 600 folder && ls folder; cat folder/a.txt   # both fail
chmod 700 folder && cat folder/a.txt                                              # works
```

- Without `x` on a folder I can't enter it, so I can't reach files inside — **for folders, `x` matters more than `r`**.

### 4.4 Ownership

```bash
sudo groupadd devops && sudo useradd -m -s /bin/bash -G devops alice && sudo useradd -m -s /bin/bash bob
sudo chown alice:devops file.txt && ls -l file.txt
sudo chgrp wmusleh file.txt && ls -l file.txt
```

| Part | Meaning |
|---|---|
| `chown alice:devops` | **Ch**ange **own**er and group |
| `chgrp wmusleh` | **Ch**ange **gr**ou**p** only |
| `sudo` | Only root can give files away |
| `chown -R` | **R**ecursive — a folder and everything inside |

### 4.5 Team folder with setgid

```bash
sudo mkdir -p /srv/project && sudo chown root:devops /srv/project && sudo chmod 2770 /srv/project && ls -ld /srv/project
sudo -iu alice bash -c 'echo "db_password=123" > /srv/project/app.conf && chmod 600 /srv/project/app.conf'
sudo usermod -aG devops bob && sudo -iu bob cat /srv/project/app.conf      # denied
sudo ls -l /srv/project/app.conf                                            # -rw------- alice devops
sudo chmod 640 /srv/project/app.conf && sudo -iu bob cat /srv/project/app.conf   # works
```

| Part | Meaning |
|---|---|
| `2770` | `2` = **setgid** (new files inherit the folder's group) + `770` (owner/group full, others nothing) |
| `ls -ld` | Show the folder itself — `drwxrws---` (`s` = setgid) |
| `bash -c '...'` | Run the quoted commands in a new Bash shell |
| Cause | Group had no read on the file (`600`) |
| Fix | `640` — owner rw, group r, others nothing |

### 4.6 Default permissions — umask

```bash
umask && touch newfile && mkdir newdir && ls -ld newfile newdir
```

| Part | Meaning |
|---|---|
| `umask` | `0022` — bits **removed** from new files/folders |
| Result | Files `666 - 022 = 644`, folders `777 - 022 = 755` |

### 4.7 Special bits

```bash
ls -ld /tmp
ls -l /usr/bin/passwd
```

| Seen as | Meaning |
|---|---|
| `drwxrwxrwt /tmp` | **Sticky bit** `t` — everyone writes, but only deletes their own files |
| `-rwsr-xr-x /usr/bin/passwd` | **Setuid** `s` — runs as the owner (root), so users can update `/etc/shadow` |

### 4.8 Clean up

```bash
sudo rm -rf /srv/project && sudo userdel -r alice && sudo userdel -r bob && sudo groupdel devops && rm -rf ~/practice/perms
```

### Quiz answers

| Question | Answer |
|---|---|
| `rwxr-x---` / `644` | `750` / `rw-r--r--` |
| `./deploy.sh` Permission denied | `chmod +x deploy.sh` |
| Can `ls` but not `cd` a folder | Missing `x` |
| setgid on a folder | New files inherit the folder's group |
| Why not `chmod 777`? | Gives everyone full access and hides the real cause |

---

## Section 5 — Processes

**Read:** Linux Journey → Processes (ps, Controlling Terminal, Process Details, Process Creation, Process Termination, Signals, kill, niceness, Process States, /proc, Job Control).

### 5.1 What is a process?

```bash
echo "My shell's PID is $$" && ps
```

| Part | Meaning |
|---|---|
| PID | **P**rocess **ID** — every running program has one |
| PPID | **P**arent PID — the process that started it |
| `$$` | PID of the current shell |
| `ps` | Processes in this terminal: PID, TTY, TIME, CMD |

### 5.2 See all processes

```bash
ps aux | head -5
ps -ef --forest | tail -15
ps -p 1 -o pid,user,comm
```

| Part | Meaning |
|---|---|
| `ps aux` | `a` all users, `u` user-oriented columns (%CPU, %MEM), `x` include processes without a terminal |
| `ps -ef --forest` | `-e` every process, `-f` full format with PPID, `--forest` draws the tree |
| `ps -p 1 -o pid,user,comm` | Only PID 1, chosen columns — PID 1 is the first process, the parent of everything |

### 5.3 Foreground, background, job control

```bash
sleep 300           # Ctrl+Z to pause
jobs
bg %1 && jobs
fg %1               # Ctrl+C to stop
```

| Key / command | Meaning |
|---|---|
| `Ctrl+Z` | **Pause** the foreground process (SIGTSTP) |
| `jobs` | Background jobs of this shell |
| `bg %1` | Resume job 1 in the background |
| `fg %1` | Bring job 1 to the foreground |
| `Ctrl+C` | **Stop** the foreground process (SIGINT) |
| `&` | Start in the background immediately |

### 5.4 Find processes

```bash
sleep 600 & sleep 700 &
jobs -l
pgrep -a sleep
ps aux | grep "[s]leep"
```

| Part | Meaning |
|---|---|
| `jobs -l` | Jobs with their PIDs |
| `pgrep -a sleep` | PIDs by name; `-a` shows the full command |
| `grep "[s]leep"` | Matches "sleep" but not grep's own line |

### 5.5 Signals and kill

| Signal | No. | Meaning | Can be handled? |
|---|---|---|---|
| `SIGTERM` | 15 | "Please stop" — default for `kill`, allows cleanup | Yes |
| `SIGKILL` | 9 | Stop **now**, no cleanup — last resort | **No** |
| `SIGINT` | 2 | Interrupt (`Ctrl+C`) | Yes |
| `SIGHUP` | 1 | Hang up — many services reload config | Yes |

```bash
kill %1 && sleep 1 && jobs
pkill -f "sleep 700" && sleep 1 && jobs
kill -l | head -3
```

| Part | Meaning |
|---|---|
| `kill %1` | SIGTERM to job 1 |
| `pkill -f "sleep 700"` | SIGTERM to processes whose **f**ull command line matches |
| `kill -l` | **L**ist signals |
| Real-life order | `kill PID` → wait → `kill -9 PID` only if still running |

### 5.6 Live monitoring

```bash
top
yes > /dev/null &
top -b -n 1 | head -12
kill %1
```

| Part | Meaning |
|---|---|
| `top` | Live view; `P` sort by CPU, `M` memory, `1` per-core, `k` kill, `q` quit |
| Header | **Load average** (1/5/15 min) — above the number of cores = overloaded |
| `yes > /dev/null &` | A CPU hog: prints "y" forever into the black hole |
| `top -b -n 1` | **B**atch mode, **1** snapshot — plain text for scripts |

### 5.7 Process states

```bash
ps -eo pid,stat,comm | head -10
```

| Code | State |
|---|---|
| `R` | Running |
| `S` | Sleeping (waiting) |
| `D` | Uninterruptible sleep (disk I/O) |
| `T` | Stopped (`Ctrl+Z`) |
| `Z` | Zombie — finished, parent hasn't collected its exit status |

### 5.8 Priority

```bash
nice -n 19 sleep 300 &
ps -o pid,ni,comm -p $!
kill $!
```

| Part | Meaning |
|---|---|
| `nice -n 19` | Lowest priority (range -20 highest … 19 lowest) |
| `$!` | PID of the last background process |
| `ni` | Niceness column |

### 5.9 /proc

```bash
sleep 300 &
ls /proc/$! | head
cat /proc/$!/status | head -6
kill $!
```

- Every process is a folder `/proc/<PID>`; `ps` and `top` just read these files.

### 5.10 Which process owns a port?

```bash
python3 -m http.server 8080 &
ss -tlnp | grep 8080
curl -sI localhost:8080 | head -1
kill %1
```

| Part | Meaning |
|---|---|
| `python3 -m http.server 8080 &` | Tiny web server on port 8080, in the background |
| `ss` | **S**ocket **s**tatistics |
| `-t` / `-l` / `-n` / `-p` | **T**CP / **l**istening / **n**umeric ports / show **p**rocess |
| `curl -sI` | Request headers only, silently — `HTTP/1.0 200 OK` |

### Quiz answers

| Question | Answer |
|---|---|
| `kill` vs `kill -9` | SIGTERM (polite, cleanup) vs SIGKILL (forced) — try `kill` first |
| Move a foreground job to background | `Ctrl+Z`, then `bg` |
| Who listens on port 80? | `sudo ss -tlnp \| grep :80` |
| PID 1 | `systemd` |
| State `Z` | Zombie |

---

# Part 2 — Lab on EC2

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
