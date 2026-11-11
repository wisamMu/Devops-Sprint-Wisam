# Day 1 — Linux Essentials (Learning)

**Date:** 2026-11-04
**Topic:** Linux essentials — filesystem, users, permissions, processes, systemd, packages
**Where:** WSL Ubuntu 24.04 (local, free)
**Goal:** Learn to find my way around Linux, manage users and permissions, and control processes — every command practised locally.
**Lab:** the hands-on EC2 lab (Session Manager, users, permissions, nginx with `systemctl` and `journalctl`) is in `day01/linux-lab.md` on the **`git-lab`** branch.

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
