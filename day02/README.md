# Day 2 — Bash Scripting

**Date:** 2026-11-05
**Topic:** Bash scripting — variables, conditionals, loops, functions, exit codes, pipes, grep/sed/awk, `set -euo pipefail`, ShellCheck
**Where:** WSL Ubuntu 24.04, practice folder `~/practice/day2`
**Goal:** Write scripts that automate routine checks safely and fail loudly when something is wrong.
**Cost:** $0 — everything ran locally.

**Reading:** [MIT Missing Semester](https://missing.csail.mit.edu/) — lecture 1 (The Shell), lecture 2 (Shell Tools and Scripting), lecture 4 (Data Wrangling).

---

# 📖 Bash symbol cheat sheet

Once each symbol has a meaning, scripts read like sentences.

### Variables

| Symbol | Meaning | Example |
|---|---|---|
| `name=value` | Store a value (no spaces around `=`) | `limit=80` |
| `$name` | Read the value | `echo $limit` |
| `"$name"` | Read it **safely** (keeps spaces) | `ls "$dir"` |
| `${name}` | Read it with clear edges | `${used}%` |
| `${name:-x}` | The value, **or `x` if empty/unset** | `${1:-80}` |
| `local name` | Variable only inside this function | `local used` |
| `export name` | Pass the variable to child programs | `export LOG_FILE` |

### Special variables

| Symbol | Meaning |
|---|---|
| `$0` | The script's name |
| `$1` `$2` … | 1st, 2nd … argument |
| `$#` | **Number** of arguments |
| `$@` / `"$@"` | All arguments (keep the quotes) |
| `$*` | All arguments as one string |
| `$?` | Exit code of the **last** command (0 = success) |
| `$$` | This shell's PID |
| `$!` | PID of the last background job |

### Running commands

| Symbol | Meaning | Example |
|---|---|---|
| `$( )` | Run a command and **use its output** | `today=$(date +%F)` |
| `$(( ))` | **Maths** | `$(( a + 1 ))` |
| `(( ))` | Number **test** (true/false) | `(( used > 80 ))` |
| `[[ ]]` | String / file **test** | `[[ -f file ]]` |
| `;` | Then run the next command, whatever happens | `cd /tmp; ls` |
| `&&` | Next command **only if** this one succeeded | `mkdir x && cd x` |
| `\|\|` | Next command **only if** this one failed | `cd x \|\| exit 1` |
| `!` | NOT | `if ! grep -q x f` |
| `&` | Run in the background | `sleep 60 &` |

### Input and output

| Symbol | Meaning | Example |
|---|---|---|
| `\|` | Pipe — output becomes the next command's input | `df \| awk ...` |
| `>` | Write output to a file (overwrite) | `echo hi > f` |
| `>>` | Append to a file | `echo hi >> f` |
| `<` | Read input from a file | `wc -l < f` |
| `2>` | Redirect **errors** | `2>/dev/null` |
| `>&2` | Send output **to** stderr | `fail ... >&2` |
| `2>&1` | Errors go where output goes | `cmd > all.log 2>&1` |
| `/dev/null` | "Black hole" — discards anything | |
| `<<'EOF'` | Heredoc — multi-line text until `EOF` | `cat > f <<'EOF'` |

### Tests inside `[[ ]]`

| Symbol | Meaning |
|---|---|
| `-f` / `-d` / `-e` | Is a file / directory / exists |
| `-r` / `-w` / `-x` | Readable / writable / executable |
| `-z` / `-n` | Empty / not empty |
| `==` / `!=` | Strings equal / not equal |
| `-eq -ne -gt -ge -lt -le` | Numbers: = ≠ > ≥ < ≤ |

### Structure

| Keyword | Meaning |
|---|---|
| `if … then … elif … else … fi` | Decisions (`fi` ends the `if`) |
| `case … in … ;; esac` | Match patterns (`esac` ends the `case`) |
| `for x in …; do … done` | Loop over a list |
| `while …; do … done` | Loop while true |
| `name() { … }` | Define a function |
| `return N` | Leave a function with an exit code |
| `exit N` | Leave the script with an exit code |
| `shift` | Drop `$1`; the others move down |

### awk

| Symbol | Meaning |
|---|---|
| `$1` `$5` (inside awk) | Column 1, column 5 — **not** script arguments |
| `NR==2` | Only line number 2 |
| `-F:` | Use `:` as the column separator |
| `gsub("%","")` | Remove every `%` |
| `print` / `printf` | Output / formatted output |
| `END { }` | Run once after the last line |

### Script header

| Line | Meaning |
|---|---|
| `#!/usr/bin/env bash` | Run this file with Bash |
| `set -e` | Stop on any error |
| `set -u` | Stop on an unset variable |
| `set -o pipefail` | A pipe fails if any part fails |

### Example — reading a line with the cheat sheet

```bash
if ! used=$(df -P "$DISK_PATH" 2>/dev/null | awk 'NR==2 {gsub("%",""); print $5}'); then
```

> **if NOT** ( store in `used` the **output of** [ `df` for **the path** (**hide errors**) **piped into** awk → **line 2** → **remove %** → **print column 5** ] ) **then** …
>
> Plain English: "Get the disk usage number. If that fails, then …"

---

## What I learned

| Section | Topics |
|---|---|
| 1. Scripts and variables | Shebang, running scripts, variables, quotes, command substitution, arithmetic, arguments, defaults, `export`, `read` |
| 2. Exit codes and conditionals | `$?`, `exit N`, `&&` / `\|\|`, `if/elif/else`, `[[ ]]` tests for numbers, strings and files, `case` |
| 3. Loops and functions | `for` (lists, globs, ranges, C-style), `while`, `until` retry loops, reading files line by line, `break`/`continue`, functions, `local`, `return` |
| 4. grep, sed, awk | Regex, searching, editing text, columns, totals, parsing `df`, `free`, `systemctl`, `curl` |
| 5. Safe scripts | `set -e`, `set -u`, `set -o pipefail`, quoting, ShellCheck, `trap`, timestamped logging |
| **Lab** | **`healthcheck.sh`** — disk, memory, URL and service checks with logging, exit codes and a 12-case failure test |

> **Lab:** `healthcheck.sh` and its step-by-step build are on the **`git-lab`** branch: `day02/lab.md`.

> In every table below, `&&` means "run the next command only if the previous one succeeded".

---

# Section 1 — Scripts and variables

### 1.1 Practice folder

```bash
mkdir -p ~/practice/day2 && cd ~/practice/day2
```

| Part | Meaning |
|---|---|
| `mkdir -p` | Create the folder; no error if it already exists |
| `cd` | Go into it |

### 1.2 First script

```bash
cat > hello.sh <<'EOF'
#!/usr/bin/env bash
echo "Hello from $USER on $(hostname)"
echo "Today is $(date +%F)"
EOF
```

| Part | Meaning |
|---|---|
| `cat > hello.sh <<'EOF' ... EOF` | Heredoc — write everything up to `EOF` into the file |
| `#!/usr/bin/env bash` | **Shebang** — run the file with Bash; `env` finds Bash wherever it's installed (more portable than `#!/bin/bash`) |
| `$USER` | Built-in environment variable: my username |
| `$(hostname)` | **Command substitution** — run the command, insert its output |
| `date +%F` | Today's date as `YYYY-MM-DD` |

```bash
bash hello.sh
chmod +x hello.sh && ./hello.sh
```

| Command | Meaning |
|---|---|
| `bash hello.sh` | Pass the file to Bash — no execute permission needed |
| `chmod +x hello.sh` | Make it executable |
| `./hello.sh` | Run it directly; the shebang picks the interpreter |

### 1.3 Variables and quotes

```bash
name="Wisam"
echo "Hi $name"
echo "Hi ${name}!"
echo 'Hi $name'
```

| Part | Meaning |
|---|---|
| `name="Wisam"` | Create a variable — ⚠️ **no spaces around `=`** (`name = "x"` runs a command called `name`) |
| `$name` | The variable's value |
| `${name}` | Same, with clear boundaries — needed in `${name}_backup` |
| `"double quotes"` | Variables **are** expanded |
| `'single quotes'` | Everything literal — prints `$name` as text |

### 1.4 Command substitution and arithmetic

```bash
today=$(date +%F)
files=$(ls | wc -l)
echo "On $today this folder has $files files"
```

| Part | Meaning |
|---|---|
| `$(...)` | Store a command's **output** in a variable |
| `ls \| wc -l` | Count the entries in this folder |

```bash
a=7; b=3
echo $(( a + b )) $(( a * b )) $(( a / b )) $(( a % b ))
```

| Part | Meaning |
|---|---|
| `;` | Separate two commands on one line |
| `$(( ... ))` | **Arithmetic expansion**, whole numbers only |
| `/` | Integer division — `7 / 3` = `2` |
| `%` | Remainder — `7 % 3` = `1` |
| Output | `10 21 2 1` |

### 1.5 Script arguments

```bash
cat > args.sh <<'EOF'
#!/usr/bin/env bash
echo "Script name: $0"
echo "First arg:   $1"
echo "Second arg:  $2"
echo "Arg count:   $#"
echo "All args:    $@"
EOF
chmod +x args.sh && ./args.sh disk memory
```

| Variable | Meaning |
|---|---|
| `$0` | The script's own name |
| `$1`, `$2` … | 1st, 2nd … argument |
| `$#` | Number of arguments |
| `$@` | All arguments — use `"$@"` to keep each one separate |

### 1.6 Default values

```bash
cat > defaults.sh <<'EOF'
#!/usr/bin/env bash
threshold="${1:-80}"
echo "Disk threshold is ${threshold}%"
EOF
chmod +x defaults.sh && ./defaults.sh && ./defaults.sh 90
```

| Part | Meaning |
|---|---|
| `${1:-80}` | Use `$1` if given, otherwise **80** |
| Output | `80%`, then `90%` |

Used later in `healthcheck.sh` so thresholds can change without editing the script.

### 1.7 Shell variables vs environment variables

```bash
color="blue"
bash -c 'echo "child sees: $color"'
export color
bash -c 'echo "child sees: $color"'
```

| Part | Meaning |
|---|---|
| `color="blue"` | **Shell** variable — only this shell sees it |
| `bash -c '...'` | Start a **child** process to run the command |
| First run | Prints nothing after the colon |
| `export color` | Make it an **environment** variable — passed to child processes |
| Second run | `child sees: blue` |

This is how configuration reaches programs and containers ("config from env vars", Day 7).

### 1.8 Reading input

```bash
read -rp "Your name: " who && echo "Welcome, $who"
```

| Part | Meaning |
|---|---|
| `read` | Read a line from the keyboard into a variable |
| `-p "..."` | Show a **p**rompt |
| `-r` | **R**aw — keep backslashes as-is (always use it) |

### Exercise — `sysinfo.sh`

Print user, hostname, date and the number of files in a folder (default: current folder).

```bash
#!/usr/bin/env bash
dir="${1:-.}"
echo "User: $USER  Host: $(hostname)"
echo "Date: $(date +%F)"
echo "Files in $dir: $(ls "$dir" | wc -l)"
```

| Part | Meaning |
|---|---|
| `${1:-.}` | Folder from `$1`, or `.` (current folder) |
| `"$dir"` | Quoted so folder names with spaces still work |

---

# Section 2 — Exit codes and conditionals

**Why:** every check is "run a test, then decide pass or fail". Exit codes are how scripts, CI pipelines and systemd know whether something worked.

### 2.1 Exit codes

Every command ends with a number: **0 = success**, **1–255 = failure**.

```bash
ls /etc > /dev/null; echo "exit code: $?"
ls /nope 2>/dev/null; echo "exit code: $?"
grep -q root /etc/passwd; echo "exit code: $?"
grep -q nobodyhere /etc/passwd; echo "exit code: $?"
true; echo $?
false; echo $?
```

| Part | Meaning | Result |
|---|---|---|
| `$?` | Exit code of the **last** command — read it immediately | |
| `ls /etc > /dev/null` | Success, output discarded | `0` |
| `ls /nope 2>/dev/null` | Can't access, error hidden | `2` |
| `grep -q` | **Q**uiet — no output, only the code | `0` found / `1` not found |
| `true` / `false` | Commands that only exit 0 / 1 | `0` / `1` |

### 2.2 Setting your own exit code

```bash
cat > code.sh <<'EOF'
#!/usr/bin/env bash
echo "about to fail"
exit 3
echo "never printed"
EOF
chmod +x code.sh && ./code.sh; echo "script exited with $?"
```

| Part | Meaning |
|---|---|
| `exit 3` | Stop here and return 3 |
| Lines after `exit` | Never run |
| Output | `about to fail`, `script exited with 3` |

### 2.3 `&&` and `||`

```bash
mkdir -p demo && echo "created"
ls /nope 2>/dev/null || echo "ls failed, handling it"
grep -q root /etc/passwd && echo "found" || echo "not found"
```

| Operator | Next command runs when… |
|---|---|
| `a && b` | `a` **succeeded** |
| `a \|\| b` | `a` **failed** |
| `a && b \|\| c` | Short if/else — ⚠️ `c` also runs if `b` fails; use `if` for anything important |

### 2.4 `if`

```bash
if grep -q root /etc/passwd; then
  echo "root user exists"
else
  echo "no root user"
fi
```

| Part | Meaning |
|---|---|
| `if COMMAND; then` | Run COMMAND; exit code **0** → run the `then` block |
| `else` | Runs on a non-zero code |
| `fi` | End of the `if` |

Bash's `if` checks **exit codes**, so any command can be a condition.

### 2.5 Tests with `[[ ... ]]`

`[[ ... ]]` is a command that exits 0 (true) or 1 (false).

**Numbers**

```bash
used=85; limit=80
if [[ $used -gt $limit ]]; then echo "ALERT: ${used}% > ${limit}%"; fi
```

| Operator | Meaning |
|---|---|
| `-eq` / `-ne` | Equal / not equal |
| `-gt` / `-ge` | Greater / greater or equal |
| `-lt` / `-le` | Less / less or equal |
| `(( used > limit ))` | Arithmetic alternative — reads naturally |

**Strings**

```bash
status="active"
[[ $status == "active" ]] && echo "running"
[[ $status != "failed" ]] && echo "not failed"
[[ -z $empty ]] && echo "empty is empty"
[[ -n $status ]] && echo "status has a value"
```

| Operator | Meaning |
|---|---|
| `==` / `!=` | Equal / not equal |
| `-z` | Empty (**z**ero length) |
| `-n` | **N**ot empty |

**Files**

```bash
[[ -f /etc/passwd ]] && echo "is a file"
[[ -d /etc ]] && echo "is a directory"
[[ -e /nope ]] || echo "does not exist"
[[ -r /etc/shadow ]] || echo "cannot read shadow"
[[ -x ./code.sh ]] && echo "code.sh is executable"
```

| Operator | Meaning |
|---|---|
| `-e` | **E**xists |
| `-f` | Regular **f**ile |
| `-d` | **D**irectory |
| `-r` / `-w` / `-x` | Readable / writable / executable by me |
| `-s` | Exists and not empty |

**Combining**

```bash
[[ -f /etc/passwd && -r /etc/passwd ]] && echo "file and readable"
[[ ! -d /nope ]] && echo "not a directory"
```

| Operator | Meaning |
|---|---|
| `&&` / `\|\|` inside `[[ ]]` | And / or |
| `!` | Not |

### 2.6 `elif` — several levels

```bash
cat > level.sh <<'EOF'
#!/usr/bin/env bash
used="${1:-50}"
if (( used >= 90 )); then
  echo "CRITICAL ${used}%"; exit 2
elif (( used >= 80 )); then
  echo "WARNING ${used}%"; exit 1
else
  echo "OK ${used}%"
fi
EOF
chmod +x level.sh
./level.sh 50; echo "code $?"
./level.sh 85; echo "code $?"
./level.sh 95; echo "code $?"
```

| Part | Meaning |
|---|---|
| `elif` | "else if" — checked only if the conditions above were false |
| Codes `0` / `1` / `2` | OK / WARNING / CRITICAL — the convention monitoring tools (Nagios) use |

### 2.7 `case` — pattern matching

```bash
cat > svc.sh <<'EOF'
#!/usr/bin/env bash
case "$1" in
  start|up)   echo "starting" ;;
  stop|down)  echo "stopping" ;;
  status)     echo "checking" ;;
  *)          echo "usage: $0 {start|stop|status}"; exit 1 ;;
esac
EOF
chmod +x svc.sh && ./svc.sh up && ./svc.sh status && ./svc.sh banana; echo "code $?"
```

| Part | Meaning |
|---|---|
| `case "$1" in ... esac` | Compare `$1` with each pattern |
| `start\|up)` | "start" **or** "up" |
| `;;` | End of the branch |
| `*)` | Anything else (default) |
| `esac` | End of `case` |

### Exercise — `checkfile.sh`

Exit 2 with usage if no argument; "missing" and exit 1 if the path doesn't exist; otherwise print file or directory.

```bash
#!/usr/bin/env bash
if [[ $# -eq 0 ]]; then echo "usage: $0 PATH"; exit 2; fi
path="$1"
if [[ ! -e $path ]]; then echo "missing"; exit 1
elif [[ -d $path ]]; then echo "directory"
else echo "file"
fi
```

| Part | Meaning |
|---|---|
| `$# -eq 0` | No arguments given |
| `! -e` | Does not exist |

---

# Section 3 — Loops and functions

### 3.1 `for` over a list

```bash
for svc in nginx ssh cron; do
  echo "checking $svc"
done
```

| Part | Meaning |
|---|---|
| `for svc in a b c` | Run the body once per word |
| `do ... done` | Loop body |

### 3.2 `for` over files

```bash
for f in *.sh; do
  echo "$f has $(wc -l < "$f") lines"
done
```

| Part | Meaning |
|---|---|
| `*.sh` | **Glob** — replaced by every matching file name |
| `wc -l < "$f"` | Count lines; `<` feeds the file in, so only the number prints |
| `"$f"` | Quoted for names with spaces |

### 3.3 `for` over numbers

```bash
for i in {1..5}; do echo "try $i"; done
for (( i=0; i<10; i+=2 )); do echo "i=$i"; done
```

| Part | Meaning |
|---|---|
| `{1..5}` | Brace expansion: 1 2 3 4 5 |
| `for (( init; condition; step ))` | C-style loop: start 0, while under 10, add 2 |

### 3.4 `while` and `until` (retry loop)

```bash
count=1
while (( count <= 3 )); do
  echo "attempt $count"
  (( count++ ))
done
```

| Part | Meaning |
|---|---|
| `while CONDITION` | Repeat while the condition succeeds |
| `(( count++ ))` | Add 1 |

```bash
attempt=1
until curl -s -o /dev/null http://localhost:8080 || (( attempt > 3 )); do
  echo "not up yet (attempt $attempt), retrying in 1s..."
  sleep 1
  (( attempt++ ))
done
echo "done waiting"
```

| Part | Meaning |
|---|---|
| `until CONDITION` | Repeat **until** the condition succeeds |
| `curl -s -o /dev/null URL` | Request silently, discard body; success if something answers |
| `\|\| (( attempt > 3 ))` | Stop after 3 attempts — never loop forever |
| `sleep 1` | Wait 1 second |

The same pattern waits for `/health` after a deploy (Day 13).

### 3.5 Reading a file line by line

```bash
printf "nginx\nssh\ncron\n" > services.txt
while IFS= read -r svc; do
  echo "service: $svc"
done < services.txt
```

| Part | Meaning |
|---|---|
| `printf "a\nb\n"` | Like `echo`, with reliable `\n` handling |
| `while read -r svc` | One line into `svc` per round |
| `IFS=` | Don't trim spaces at the start/end of lines |
| `-r` | Keep backslashes |
| `done < services.txt` | Feed the file into the loop |

`for line in $(cat file)` breaks on spaces — use `while read`.

### 3.6 `break` and `continue`

```bash
for n in 1 2 3 4 5 6; do
  (( n == 2 )) && continue
  (( n == 5 )) && break
  echo "n=$n"
done
```

| Keyword | Meaning |
|---|---|
| `continue` | Skip to the next round |
| `break` | Leave the loop |
| Output | `n=1`, `n=3`, `n=4` |

### 3.7 Functions

```bash
cat > funcs.sh <<'EOF'
#!/usr/bin/env bash

greet() {
  local who="$1"
  echo "Hello, $who"
}

is_even() {
  (( $1 % 2 == 0 ))
}

greet "Wisam"
for n in 3 4; do
  if is_even "$n"; then echo "$n is even"; else echo "$n is odd"; fi
done
EOF
chmod +x funcs.sh && ./funcs.sh
```

| Part | Meaning |
|---|---|
| `greet() { ... }` | Define a function — before calling it |
| `"$1"` inside | The **function's** argument, not the script's |
| `local who=...` | Variable visible only inside the function |
| `is_even` | Exit code = last command's; `(( ))` gives 0 when true, so it works in `if` |

### 3.8 Output vs exit code

```bash
cat > ret.sh <<'EOF'
#!/usr/bin/env bash

disk_used() {
  df --output=pcent / | tail -1 | tr -dc '0-9'
}

check_ok() {
  [[ "$1" -lt 80 ]] && return 0
  return 1
}

used=$(disk_used)
echo "root disk used: ${used}%"
if check_ok "$used"; then echo "OK"; else echo "TOO FULL"; fi
EOF
chmod +x ret.sh && ./ret.sh
```

| Part | Meaning |
|---|---|
| `echo` + `$(func)` | Return **data** — `used=$(disk_used)` |
| `return 0` / `return 1` | Return **pass/fail** (numbers 0–255 only) |
| `df --output=pcent /` | Only the Use% column for `/` |
| `tail -1` | Skip the header |
| `tr -dc '0-9'` | Delete everything **except** (`-c`) digits: `" 42%"` → `42` |

Pattern for `healthcheck.sh`: **one function per check, returning pass or fail**.

### Exercise — `multi.sh`

```bash
#!/usr/bin/env bash
check_dir() {
  if [[ -d "$1" ]]; then echo "OK $1"; return 0; fi
  echo "FAIL $1"; return 1
}

failures=0
for p in /etc /tmp /nope /var/log; do
  check_dir "$p" || (( failures++ ))
done

if (( failures == 0 )); then echo "All good"; exit 0; fi
echo "$failures failures"; exit 1
```

| Part | Meaning |
|---|---|
| `check_dir "$p" \|\| (( failures++ ))` | Count only failed checks |
| Result | `OK /etc`, `OK /tmp`, `FAIL /nope`, `OK /var/log`, `1 failures`, exit 1 |

---

# Section 4 — grep, sed and awk

| Tool | Best for |
|---|---|
| `grep` | **Finding** lines |
| `sed` | **Editing** text — replace, delete, print ranges |
| `awk` | **Columns** — pick fields, compare numbers, totals |

### 4.1 Sample data

```bash
cd ~/practice/day2 && cat > app.log <<'EOF'
2026-11-05 10:00:01 INFO  user=alice action=login  ms=120
2026-11-05 10:00:05 WARN  user=bob   action=upload ms=950
2026-11-05 10:01:10 ERROR user=alice action=upload ms=3100
2026-11-05 10:02:00 INFO  user=carol action=login  ms=80
2026-11-05 10:03:30 ERROR user=bob   action=delete ms=2400
2026-11-05 10:04:00 INFO  user=alice action=logout ms=40
EOF
```

Columns: date, time, level, user, action, duration (ms).

### 4.2 grep

```bash
grep -n ERROR app.log
grep -i error app.log | wc -l
grep -E "WARN|ERROR" app.log
grep -o "user=[a-z]*" app.log | sort | uniq -c
grep -A1 WARN app.log
grep -w "ms=80" app.log
```

| Option | Meaning |
|---|---|
| `-n` | Line **n**umbers |
| `-i` | Ignore case |
| `-E "A\|B"` | Extended regex: A or B |
| `-o` | Print **o**nly the matching part |
| `user=[a-z]*` | `user=` followed by lowercase letters |
| `-A1` | Also 1 line **A**fter (`-B` before, `-C` both) |
| `-w` | Whole **w**ords only |

**Regex quick reference**

| Pattern | Matches |
|---|---|
| `.` | Any one character |
| `*` | Previous item 0+ times |
| `+` | Previous item 1+ times (`-E`) |
| `[0-9]` / `[a-z]` | A digit / a lowercase letter |
| `^` / `$` | Start / end of line |
| `{3}` | Exactly 3 times (`-E`) |

### 4.3 sed

```bash
sed 's/ERROR/E!/' app.log
sed 's/user=//g' app.log
sed -n '2,4p' app.log
sed '/INFO/d' app.log
sed -E 's/ms=([0-9]+)/\1 ms/' app.log
```

| Command | Meaning |
|---|---|
| `s/OLD/NEW/` | **S**ubstitute the first match per line |
| `s/OLD/NEW/g` | **G**lobal — every match |
| `-n '2,4p'` | Don't print by default; **p**rint lines 2–4 |
| `/INFO/d` | **D**elete matching lines |
| `-E` + `( )` + `\1` | Capture a group and reuse it: `ms=120` → `120 ms` |

These print the result; the file is unchanged. Editing in place:

```bash
cp app.log app.bak && sed -i 's/carol/CAROL/' app.bak && grep CAROL app.bak
```

| Part | Meaning |
|---|---|
| `cp app.log app.bak` | Work on a copy |
| `sed -i` | Edit the file **i**n place |

### 4.4 awk

```bash
awk '{print $3, $4}' app.log
awk '$3 == "ERROR" {print $2, $4}' app.log
awk '{print NR": "$3}' app.log
awk '{print NF}' app.log | head -1
```

| Part | Meaning |
|---|---|
| `$1`, `$2` … / `$0` | Columns / whole line |
| `'{print $3, $4}'` | Print columns 3 and 4 of every line |
| `$3 == "ERROR" {…}` | **Pattern** — act only on matching lines |
| `NR` | Current line number |
| `NF` | Number of fields on the line |

**Custom separators**

```bash
awk -F'ms=' '{print $2}' app.log
awk -F: '{print $1, $7}' /etc/passwd | head -3
```

| Part | Meaning |
|---|---|
| `-F'ms='` | Split on the text `ms=` — `$2` is the number |
| `-F:` | Split on colons |

**Maths**

```bash
awk -F'ms=' '{sum += $2} END {print "total ms:", sum, "avg:", sum/NR}' app.log
awk -F'ms=' '$2 > 1000 {slow++} END {print slow, "slow requests"}' app.log
```

| Part | Meaning |
|---|---|
| `{sum += $2}` | Add each value |
| `END {…}` | Run once after the last line |
| `$2 > 1000 {slow++}` | Count values over 1000 |

**Formatting**

```bash
awk '{printf "%-6s %-12s %s\n", $3, $4, $6}' app.log
```

| Part | Meaning |
|---|---|
| `printf` | Formatted output |
| `%-6s` | Left-aligned string, 6 characters wide |

### 4.5 Parsing real system output (used in `healthcheck.sh`)

**Disk usage %**

```bash
df -P / | awk 'NR==2 {gsub("%",""); print $5}'
```

| Part | Meaning |
|---|---|
| `df -P /` | Disk usage of `/`, **P**OSIX format (one line per disk) |
| `NR==2` | Skip the header |
| `gsub("%","")` | Remove `%` |
| `print $5` | Use% — e.g. `42` |

**Memory available %**

```bash
free -m
free -m | awk '/^Mem:/ {printf "%d\n", $7/$2*100}'
```

| Part | Meaning |
|---|---|
| `free -m` | Memory in MB: total, used, free, shared, buff/cache, **available** |
| `/^Mem:/` | The `Mem:` line |
| `$7/$2*100` | available ÷ total × 100 |
| `%d` | Whole number |

Use **available**, not **free** — Linux uses spare memory as cache.

**Service state**

```bash
systemctl is-active cron
```

| Part | Meaning |
|---|---|
| `is-active` | Prints `active`/`inactive`; exit code 0 when active — no parsing needed |

**HTTP status**

```bash
curl -s -o /dev/null -w "%{http_code}\n" --max-time 5 https://example.com
```

| Part | Meaning |
|---|---|
| `-o /dev/null` | Discard the body |
| `-w "%{http_code}"` | Print only the status code |
| `--max-time 5` | Give up after 5 seconds |

### Exercise answers

```bash
grep -c ERROR app.log                                                         # 1. ERROR lines → 2
grep ERROR app.log | awk '{print $4}' | sort | uniq -c | sort -rn | head -1   # 2. user with most errors (alice/bob tie)
sed 's/user=//' app.log                                                       # 3. lines without "user="
awk -F'ms=' '/ERROR/ {sum += $2; n++} END {print sum/n}' app.log              # 4. average ms of errors → 2750
```

---

# Section 5 — Safe scripts

**Why:** by default Bash **keeps going after errors**, treats misspelled variables as empty, and splits values with spaces. A deploy script that ignores a failed step can do real damage.

### 5.1 The problem

```bash
cat > unsafe.sh <<'EOF'
#!/usr/bin/env bash
cd /does/not/exist
echo "I am now in: $(pwd)"
echo "pretending to delete files here..."
EOF
chmod +x unsafe.sh && ./unsafe.sh; echo "exit code: $?"
```

| What happened | Why it's dangerous |
|---|---|
| `cd` failed, script **continued** | Keeps working in the **wrong folder** |
| Final exit code **0** | CI or cron believes it **succeeded** |

### 5.2 `set -e` — stop on the first error

```bash
sed -i '2i set -e' unsafe.sh && cat unsafe.sh && ./unsafe.sh; echo "exit code: $?"
```

| Part | Meaning |
|---|---|
| `sed -i '2i set -e'` | **I**nsert `set -e` as line 2 |
| `set -e` | **E**xit as soon as a command fails |
| Result | Stops at `cd`, exit code **1** ✅ |

`set -e` does **not** trigger for commands that are being tested: `if`/`while`/`until` conditions, commands before `&&` or `||`, and commands prefixed with `!`.

### 5.3 `set -u` — no undefined variables

```bash
cat > typo.sh <<'EOF'
#!/usr/bin/env bash
backup_dir="/tmp/backup"
echo "Cleaning: ${backup_dri}/old"
EOF
chmod +x typo.sh && ./typo.sh
sed -i '2i set -u' typo.sh && ./typo.sh; echo "exit code: $?"
```

| Run | Result |
|---|---|
| Without `-u` | `Cleaning: /old` — the typo silently became empty |
| With `-u` | `backup_dri: unbound variable`, script stops ✅ |

```bash
bash -uc 'echo "value: ${MAYBE:-none}"'
```

| Part | Meaning |
|---|---|
| `bash -uc` | Run with `set -u` |
| `${MAYBE:-none}` | A default makes an optional variable safe under `-u` |

### 5.4 `set -o pipefail` — failures inside pipes

```bash
bash -c 'cat /nope | wc -l; echo "exit: $?"'
bash -c 'set -o pipefail; cat /nope | wc -l; echo "exit: $?"'
```

| Run | Exit code | Why |
|---|---|---|
| Without | `0` | A pipe returns the **last** command's code (`wc` succeeded) |
| With | `1` | The pipe fails if **any** part fails |

### 5.5 Standard header

```bash
#!/usr/bin/env bash
set -euo pipefail
```

| Flag | Protects against |
|---|---|
| `-e` | Continuing after a failure |
| `-u` | Typos and unset variables |
| `-o pipefail` | Hidden failures inside pipes |

### 5.6 Quoting

```bash
mkdir -p "quote test" && touch "quote test/a.txt"
dir="quote test"
ls $dir
ls "$dir"
```

| Command | Result |
|---|---|
| `ls $dir` | ❌ Split into `quote` and `test` — both fail |
| `ls "$dir"` | ✅ One argument |

```bash
args_demo() { echo "count: $#"; }
set -- "a b" c
args_demo $@
args_demo "$@"
```

| Part | Meaning |
|---|---|
| `set -- "a b" c` | Set the arguments to `a b` and `c` |
| `$@` unquoted | `count: 3` — split |
| `"$@"` | `count: 2` — original arguments ✅ |

**Rule:** always quote `"$var"`, `"$1"`, `"$@"`, `"$(cmd)"`.

### 5.7 ShellCheck

```bash
cat > buggy.sh <<'EOF'
#!/usr/bin/env bash
dir=$1
cd $dir
for f in $(ls *.log); do
  echo Processing $f
done
if [ $count -gt 5 ]; then echo many; fi
EOF
shellcheck buggy.sh
```

| Code | Problem | Fix |
|---|---|---|
| **SC2086** | Unquoted variable — splits on spaces | `"$dir"`, `"$f"` |
| **SC2164** | `cd` may fail and the script continues | `cd "$dir" \|\| exit 1` |
| **SC2045** | Looping over `ls` output | `for f in *.log` |
| **SC2154** | `count` used but never set | Define it or `${count:-0}` |

Every code is explained at `https://www.shellcheck.net/wiki/SC2086` (swap in the code).

Fixed version:

```bash
cat > buggy.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
dir="${1:-.}"
count=0
cd "$dir" || exit 1
for f in *.log; do
  [[ -e $f ]] || continue
  echo "Processing $f"
  (( count++ )) || true
done
if (( count > 5 )); then echo "many"; fi
EOF
shellcheck buggy.sh && echo "ShellCheck: clean"
```

| Part | Meaning |
|---|---|
| `[[ -e $f ]] \|\| continue` | No `.log` files → the glob stays literal `*.log`; skip it |
| `(( count++ )) \|\| true` | ⚠️ `(( count++ ))` returns **1** when count was 0, which stops a `set -e` script; `\|\| true` prevents it |
| Safer alternative | `count=$(( count + 1 ))` |

### 5.8 `trap` — cleanup on exit

```bash
cat > trap.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
tmp=$(mktemp)
trap 'rm -f "$tmp"; echo "cleaned up $tmp"' EXIT
echo "working in $tmp"
false
echo "never reached"
EOF
chmod +x trap.sh && ./trap.sh; echo "exit code: $?"
```

| Part | Meaning |
|---|---|
| `mktemp` | Create a unique temp file, print its path |
| `trap 'CMD' EXIT` | Run CMD whenever the script exits — success, failure or `Ctrl+C` |
| `false` | Fails → `set -e` stops the script → trap still runs ✅ |

### 5.9 Timestamped logging

```bash
cat > log.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
LOG_FILE="${LOG_FILE:-./demo.log}"

log() {
  local level="$1"; shift
  printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*" | tee -a "$LOG_FILE"
}

log INFO "starting"
log WARN "disk at 85%"
log ERROR "service nginx is down" >&2
EOF
chmod +x log.sh && ./log.sh && echo "--- file ---" && cat demo.log
```

| Part | Meaning |
|---|---|
| `LOG_FILE="${LOG_FILE:-./demo.log}"` | Env variable if set, else a default |
| `local level="$1"; shift` | Save the level; `shift` drops it so `$*` is the message |
| `date '+%Y-%m-%d %H:%M:%S'` | Timestamp `2026-11-05 10:30:00` |
| `printf '%s [%s] %s\n'` | Format: time, `[LEVEL]`, message |
| `tee -a "$LOG_FILE"` | Screen **and** append to the file |
| `>&2` | Send that line to stderr |

### Exercises

1. `shellcheck *.sh` on all practice scripts and fix every warning.
2. Add `set -euo pipefail` to `multi.sh`. It still works because `check_dir "$p" || (( failures++ ))` is protected by `||`; a bare `(( failures++ ))` would stop the script when failures is 0. `failures=$(( failures + 1 ))` avoids the trap entirely.

---

# Section 6 — OverTheWire Bandit (planned)

A free game: each level is a Linux server reached over SSH; find the password for the next level.

```bash
ssh bandit0@bandit.labs.overthewire.org -p 2220
```

| Part | Meaning |
|---|---|
| `ssh` | Secure remote shell |
| `bandit0@…` | User `bandit0` on the game server |
| `-p 2220` | Port 2220 (SSH normally uses 22) |
| First connect | Answer `yes` to save the server's fingerprint in `~/.ssh/known_hosts` |

```bash
mkdir -p ~/bandit && chmod 700 ~/bandit && touch ~/bandit/passwords.txt && chmod 600 ~/bandit/passwords.txt
```

Private place for passwords — **never committed to Git**.

| Level → next | Skill |
|---|---|
| 0 → 1 | `ls`, `cat` |
| 1 → 2 | File named `-` — pass a path |
| 2 → 3 | Spaces in names — quotes |
| 3 → 4 | Hidden files — `ls -la` |
| 4 → 5 | `file ./*` |
| 5 → 6 | `find` by size and permissions |
| 6 → 7 | `find /` by owner/group, `2>/dev/null` |
| 7 → 8 | `grep` |
| 8 → 9 | `sort \| uniq -u` |
| 9 → 10 | `strings` |
| 10 → 11 | `base64 -d` |
| 11 → 12 | ROT13 with `tr` |
| 12 → 13 | `xxd -r`, `file`, repeated decompression |
| 13 → 14 | SSH private key, `chmod 600` |
| 14 → 15 | `nc` to a port |
| 15 → 16 | `openssl s_client` |

Progress notes (commands only, no passwords) will be added here.


---

## Key takeaways

| Topic | Remember |
|---|---|
| Header | `#!/usr/bin/env bash` + `set -euo pipefail` in every script |
| Variables | No spaces around `=`; always `"$var"`; `${1:-default}` for optional values |
| Exit codes | 0 = success; `$?`; `exit N`; CI and cron rely on them |
| Conditions | `if` checks exit codes; `[[ ]]` for strings/files, `(( ))` for numbers |
| Loops | `for x in list`, `while read -r line`, `until … \|\| (( tries > N ))` |
| Functions | `local` variables; output via `echo`, pass/fail via `return` |
| Text | `grep` finds, `sed` edits, `awk` reads columns and does maths |
| Traps | `(( x++ ))` returns 1 when x is 0 — stops a `set -e` script |
| Quality | `shellcheck` every script; `trap … EXIT` for cleanup; timestamped `log` function |

