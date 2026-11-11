[⬅ Back to labs](../SPRINT.md)

> **Learning notes** for this day are on the **`docs`** branch: `day02/README.md`.

# Lab — healthcheck.sh

**Deliverable from the sprint plan:** "Write `healthcheck.sh` to check disk usage, memory, a URL and a service. It exits non-zero on failure, logs with timestamps and passes ShellCheck cleanly."

**File:** [`day02/healthcheck.sh`](healthcheck.sh)
**Time:** ~2 hours
**Result:** ✅ all requirements met

| Requirement | How it's met |
|---|---|
| Checks disk | `check_disk` — `df -P` + `awk`, fails above `DISK_MAX_PCT` |
| Checks memory | `check_memory` — `free -m` **available** column, fails below `MEM_MIN_PCT` |
| Checks a URL | `check_url` — `curl` status code, passes on 2xx/3xx |
| Checks a service | `check_service` — `systemctl is-active` |
| Exits non-zero on failure | `exit 1` when any check fails, `exit 2` for bad usage |
| Logs with timestamps | `log` function — `YYYY-MM-DD HH:MM:SS [LEVEL] message`, screen + file |
| Passes ShellCheck | `shellcheck healthcheck.sh` → no warnings |

## What it looks like

```text
$ ./healthcheck.sh
2026-11-05 13:53:05 [INFO] Health check started on SD-LP-W10-wmusleh
2026-11-05 13:53:05 [OK  ] disk: / is 1% used (limit 80%)
2026-11-05 13:53:05 [OK  ] memory: 93% available (min 10%)
2026-11-05 13:53:05 [OK  ] url: https://example.com returned 200
2026-11-05 13:53:05 [OK  ] service: cron is active
2026-11-05 13:53:05 [INFO] Summary: 4 passed, 0 failed - all checks OK
$ echo $?
0

$ DISK_MAX_PCT=0 ./healthcheck.sh
2026-11-05 13:53:10 [INFO] Health check started on SD-LP-W10-wmusleh
2026-11-05 13:53:10 [FAIL] disk: / is 1% used (limit 0%)
2026-11-05 13:53:10 [OK  ] memory: 93% available (min 10%)
2026-11-05 13:53:10 [OK  ] url: https://example.com returned 200
2026-11-05 13:53:10 [OK  ] service: cron is active
2026-11-05 13:53:10 [FAIL] Summary: 3 passed, 1 failed
$ echo $?
1
```

## Design

```text
main
 ├─ parse option (--help / unknown → exit 2)
 ├─ log INFO "started"
 ├─ check_disk     ─┐
 ├─ check_memory    ├─ each one: read → guard empty → compare → pass/fail
 ├─ check_url       │  never crashes the script; updates passed/failed
 ├─ check_service  ─┘
 └─ failed > 0 ? exit 1 : exit 0
```

| Design rule | Why |
|---|---|
| One function per check | Easy to read, test and add new checks |
| A check never crashes the script | Every check runs and reports, even after an earlier failure |
| Config from environment variables with defaults | Change limits without editing code (twelve-factor) |
| `pass`/`fail` helpers update counters | One place decides the final exit code |
| FAIL lines go to stderr | Still visible when normal output is hidden (`> /dev/null`) |
| Meaningful exit codes 0 / 1 / 2 | Cron, CI and deploy pipelines act on them |

## Configuration

| Variable | Default | Meaning |
|---|---|---|
| `DISK_PATH` | `/` | Filesystem to check |
| `DISK_MAX_PCT` | `80` | Fail if usage is **above** this % |
| `MEM_MIN_PCT` | `10` | Fail if available memory is **below** this % |
| `CHECK_URL` | `https://example.com` | Must return 2xx or 3xx |
| `CHECK_SERVICE` | `cron` | systemd service that must be `active` |
| `LOG_FILE` | `./healthcheck.log` | Log file (appended; ignored by Git) |

Set a variable **for one run only** by putting it before the command:

```bash
CHECK_SERVICE=nginx DISK_MAX_PCT=90 ./healthcheck.sh
```

## Exit codes

| Code | Meaning |
|---|---|
| `0` | All checks passed |
| `1` | At least one check failed |
| `2` | Wrong usage (unknown option) |

## Step 7 — Skeleton and logging

```bash
cd ~/Devops-Sprint-Wisam/day02 && touch healthcheck.sh && chmod +x healthcheck.sh && code healthcheck.sh
```

| Part | Meaning |
|---|---|
| `touch` | Create the empty file |
| `chmod +x` | Make it executable |
| `code healthcheck.sh` | Open in VS Code (WSL) |

Header, configuration, counters and logging:

```bash
set -euo pipefail

DISK_PATH="${DISK_PATH:-/}"
DISK_MAX_PCT="${DISK_MAX_PCT:-80}"
MEM_MIN_PCT="${MEM_MIN_PCT:-10}"
CHECK_URL="${CHECK_URL:-https://example.com}"
CHECK_SERVICE="${CHECK_SERVICE:-cron}"
LOG_FILE="${LOG_FILE:-./healthcheck.log}"

passed=0
failed=0

log() {
  local level="$1"
  shift
  printf '%s [%-4s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*" | tee -a "$LOG_FILE"
}

pass() {
  log OK "$*"
  passed=$(( passed + 1 ))
}

fail() {
  log FAIL "$*" >&2
  failed=$(( failed + 1 ))
}
```

| Part | Meaning |
|---|---|
| `set -euo pipefail` | Stop on errors, unset variables, pipe failures |
| `"${VAR:-default}"` | Read from the environment, fall back to a default |
| `passed=0` / `failed=0` | Counters for the summary |
| `log` | `timestamp [LEVEL] message` to screen and file |
| `%-4s` | Pad the level to 4 characters so columns line up |
| `shift` + `"$*"` | Drop the level, use the rest as the message |
| `tee -a "$LOG_FILE"` | Print **and** append to the log |
| `pass` / `fail` | Log and count; `fail` writes to stderr (`>&2`) |
| `passed=$(( passed + 1 ))` | Safe under `set -e` — `(( passed++ ))` returns 1 when it's 0 and would stop the script |

Keep the log out of Git:

```bash
echo "healthcheck.log" >> ~/Devops-Sprint-Wisam/.gitignore
```

| Part | Meaning |
|---|---|
| `.gitignore` | Files Git never tracks |
| `>>` | Append (creates the file if missing) |

Test a config override:

```bash
LOG_FILE=/tmp/hc-test.log ./healthcheck.sh && cat /tmp/hc-test.log
```

`VAR=value command` sets the variable for that one command only.

## Step 8 — Disk check

```bash
check_disk() {
  local used
  if ! used=$(df -P "$DISK_PATH" 2>/dev/null | awk 'NR==2 {gsub("%",""); print $5}'); then
    fail "disk: cannot read usage for ${DISK_PATH}"
    return
  fi

  if [[ -z $used ]]; then
    fail "disk: no usage data for ${DISK_PATH}"
  elif (( used > DISK_MAX_PCT )); then
    fail "disk: ${DISK_PATH} is ${used}% used (limit ${DISK_MAX_PCT}%)"
  else
    pass "disk: ${DISK_PATH} is ${used}% used (limit ${DISK_MAX_PCT}%)"
  fi
}
```

| Part | Meaning |
|---|---|
| `local used` then assign | `local used=$(cmd)` would hide the command's exit code (ShellCheck SC2155) |
| `df -P "$DISK_PATH"` | Usage in POSIX format, one line per filesystem |
| `2>/dev/null` | Hide the error; we report it ourselves |
| `awk 'NR==2 {gsub("%",""); print $5}'` | Line 2, remove `%`, print Use% |
| `if ! used=$(…)` | If the pipe fails (pipefail), log FAIL instead of crashing |
| `return` | Leave the function; other checks still run |
| `[[ -z $used ]]` | Guard against empty output |
| `(( used > DISK_MAX_PCT ))` | Fail if above the limit |

Tests and what I found:

| Command | Result |
|---|---|
| `./healthcheck.sh` | OK — `/` is 1% used (1007 GB WSL disk) |
| `DISK_MAX_PCT=1 ./healthcheck.sh` | Still **OK** — `1 > 1` is false. **Boundary case:** at exactly the limit, the check passes |
| `DISK_MAX_PCT=0 ./healthcheck.sh` | FAIL ✅ |
| `DISK_PATH=/nope ./healthcheck.sh` | FAIL "cannot read usage", script didn't crash ✅ |
| `df -h /` | Confirms the 1% the script printed |

## Step 9 — Memory check

```bash
free -m
```

| Column | Meaning |
|---|---|
| `$2` total | All RAM |
| `$4` free | Completely unused — misleading, looks low on healthy systems |
| `$6` buff/cache | Cache, released when programs need memory |
| `$7` **available** | What programs can really get — **the one we check** |

```bash
check_memory() {
  local avail_pct
  if ! avail_pct=$(free -m | awk '/^Mem:/ {printf "%d", $7 / $2 * 100}'); then
    fail "memory: cannot read memory usage"
    return
  fi

  if [[ -z $avail_pct ]]; then
    fail "memory: no memory data"
  elif (( avail_pct < MEM_MIN_PCT )); then
    fail "memory: only ${avail_pct}% available (min ${MEM_MIN_PCT}%)"
  else
    pass "memory: ${avail_pct}% available (min ${MEM_MIN_PCT}%)"
  fi
}
```

| Part | Meaning |
|---|---|
| `/^Mem:/` | The line starting with `Mem:` |
| `$7 / $2 * 100` | available ÷ total × 100 |
| `printf "%d"` | Whole number — Bash maths has no decimals |
| `(( avail_pct < MEM_MIN_PCT ))` | `<` here (less memory is bad), `>` for disk (more usage is bad) |

| Test | Result |
|---|---|
| `./healthcheck.sh` | OK — 93% available |
| `MEM_MIN_PCT=101 ./healthcheck.sh` | FAIL ✅ |
| `DISK_MAX_PCT=0 MEM_MIN_PCT=101 ./healthcheck.sh` | `0 passed, 2 failed` — the first failure didn't stop the second ✅ |

Low memory is what froze the Day 1 EC2 — this check would have caught it.

## Step 10 — URL check

| Code | Meaning | Verdict |
|---|---|---|
| `200` | OK | pass |
| `301` / `302` | Redirect | pass |
| `404` | Not found | fail |
| `500` / `503` | Server error | fail |
| `000` | No answer (down, DNS, timeout) — curl's value, not real HTTP | fail |

```bash
check_url() {
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$CHECK_URL" 2>/dev/null) || true

  if [[ $code =~ ^[23][0-9][0-9]$ ]]; then
    pass "url: ${CHECK_URL} returned ${code}"
  elif [[ $code == "000" || -z $code ]]; then
    fail "url: ${CHECK_URL} is unreachable"
  else
    fail "url: ${CHECK_URL} returned ${code}"
  fi
}
```

| Part | Meaning |
|---|---|
| `curl -s` | Silent |
| `-o /dev/null` | Discard the body |
| `-w '%{http_code}'` | Write out only the status code |
| `--max-time 5` | Never hang longer than 5 s |
| `\|\| true` | curl exits non-zero when it can't connect; keep the `000` instead of letting `set -e` stop the script |
| `=~` | "Matches this regular expression" |
| `^[23][0-9][0-9]$` | Any 2xx or 3xx code |

Tested against a local web server:

```bash
python3 -m http.server 8000 >/dev/null 2>&1 &
CHECK_URL=http://localhost:8000/ ./healthcheck.sh          # 200 → OK
CHECK_URL=http://localhost:8000/missing ./healthcheck.sh   # 404 → FAIL
kill %1                                                    # stop the server
CHECK_URL=http://localhost:8000/ ./healthcheck.sh          # unreachable → FAIL
./healthcheck.sh                                           # example.com 200 → OK
```

| Part | Meaning |
|---|---|
| `python3 -m http.server 8000` | Serve the current folder on port 8000 |
| `>/dev/null 2>&1 &` | Hide its log, run in the background |
| `kill %1` | Stop background job 1 |

All four behaved as designed ✅

## Step 11 — Service check

```bash
systemctl is-active cron; echo "exit code: $?"
systemctl is-active nope; echo "exit code: $?"
```

| Output | Exit code | Meaning |
|---|---|---|
| `active` | 0 | Running |
| `inactive` | non-zero | Stopped or doesn't exist |
| `failed` | non-zero | Crashed |
| `activating` | non-zero | Starting |

```bash
check_service() {
  local state
  if ! command -v systemctl >/dev/null 2>&1; then
    fail "service: systemctl not available, cannot check ${CHECK_SERVICE}"
    return
  fi

  state=$(systemctl is-active "$CHECK_SERVICE" 2>/dev/null) || true

  if [[ $state == "active" ]]; then
    pass "service: ${CHECK_SERVICE} is active"
  else
    fail "service: ${CHECK_SERVICE} is ${state:-unknown}"
  fi
}
```

| Part | Meaning |
|---|---|
| `command -v systemctl` | Is the command available? (containers often have no systemd) |
| `>/dev/null 2>&1` | Hide all output |
| `\|\| true` | Don't let `set -e` stop the script when the service isn't active |
| `${state:-unknown}` | Show the state, or `unknown` if empty |

WSL check before starting: systemd is PID 1 and `systemctl is-system-running` → `running`, so the check works locally.

Break-fix exercise:

```bash
sudo systemctl stop cron && ./healthcheck.sh     # FAIL: cron is inactive — detected
sudo systemctl start cron && ./healthcheck.sh    # OK: cron is active — fixed and verified
```

Workflow for the Day 5 drill: **run the healthcheck → it points to the fault → fix → run again**.

## Step 12 — Summary, exit code and `--help`

Problem before this step: `DISK_MAX_PCT=0 ./healthcheck.sh` showed `1 failed` but **exit code 0** — cron or CI would think everything was fine.

```bash
main() {
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    "") ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  log INFO "Health check started on $(hostname)"

  check_disk
  check_memory
  check_url
  check_service

  if (( failed > 0 )); then
    log FAIL "Summary: ${passed} passed, ${failed} failed"
    exit 1
  fi

  log INFO "Summary: ${passed} passed, ${failed} failed - all checks OK"
  exit 0
}

main "$@"
```

| Part | Meaning |
|---|---|
| `"${1:-}"` | First argument or empty — keeps `set -u` happy |
| `-h\|--help)` | Show help, exit 0 |
| `"")` | No argument — continue |
| `*)` | Unknown option → error + help to stderr, exit **2** |
| `(( failed > 0 ))` | Any check failed? |
| `exit 1` / `exit 0` | Tell the caller the result |
| `main "$@"` | Run `main` with the script's arguments |

`usage` prints the help text with a heredoc (`cat <<'EOF' … EOF`).

Using it like a real tool:

```bash
./healthcheck.sh > /dev/null && echo "✅ healthy" || echo "❌ unhealthy"
CHECK_SERVICE=nope ./healthcheck.sh > /dev/null && echo "✅ healthy" || echo "❌ unhealthy"
```

| Result | Why |
|---|---|
| `✅ healthy` | Exit 0 |
| `[FAIL] service: nope is inactive` then `❌ unhealthy` | stdout hidden, but FAIL lines go to stderr and stay visible; exit 1 |

## Step 13 — ShellCheck and failure testing

```bash
bash -n healthcheck.sh && echo "syntax OK"
shellcheck healthcheck.sh && echo "ShellCheck: clean"
shellcheck --severity=style --enable=all healthcheck.sh
```

| Command | Meaning | Result |
|---|---|---|
| `bash -n` | Syntax check without running | `syntax OK` ✅ |
| `shellcheck` | Lint for bugs | **No warnings** ✅ |
| `--severity=style --enable=all` | Strict mode: optional style tips | Only optional tips (SC2250 "use `${var}` braces", SC2312 "date's exit code is masked") — not bugs |

### Real "disk full" test with a tiny disk

```bash
sudo mkdir -p /mnt/tiny && sudo mount -t tmpfs -o size=10M tmpfs /mnt/tiny && df -h /mnt/tiny
sudo dd if=/dev/zero of=/mnt/tiny/bigfile bs=1M count=9 status=none && df -h /mnt/tiny
DISK_PATH=/mnt/tiny ./healthcheck.sh; echo "exit code: $?"          # FAIL ~90%, exit 1
sudo rm /mnt/tiny/bigfile && DISK_PATH=/mnt/tiny ./healthcheck.sh; echo "exit code: $?"   # OK, exit 0
sudo umount /mnt/tiny && sudo rmdir /mnt/tiny
```

| Part | Meaning |
|---|---|
| `mount -t tmpfs -o size=10M tmpfs /mnt/tiny` | Attach a 10 MB disk that lives in RAM |
| `dd if=/dev/zero of=… bs=1M count=9` | Write 9 MB of zeros → ~90% full |
| `rm bigfile` | Free the space (the fix) |
| `umount` / `rmdir` | Detach the disk, remove the folder |

### Failure test matrix

| # | Test | Command | Expected | Exit |
|---|---|---|---|---|
| 1 | All healthy | `./healthcheck.sh` | 4 OK | 0 ✅ |
| 2 | Disk over limit | `DISK_MAX_PCT=0 ./healthcheck.sh` | disk FAIL | 1 ✅ |
| 3 | Disk path missing | `DISK_PATH=/nope ./healthcheck.sh` | "cannot read usage" | 1 ✅ |
| 4 | Disk really full | tmpfs test above | disk FAIL ~90% | 1 ✅ |
| 5 | Low memory | `MEM_MIN_PCT=101 ./healthcheck.sh` | memory FAIL | 1 ✅ |
| 6 | URL 404 | `CHECK_URL=https://example.com/nope ./healthcheck.sh` | url FAIL (404) | 1 ✅ |
| 7 | URL unreachable | `CHECK_URL=http://localhost:9 ./healthcheck.sh` | "unreachable" | 1 ✅ |
| 8 | Service missing | `CHECK_SERVICE=nope ./healthcheck.sh` | service FAIL | 1 ✅ |
| 9 | Service stopped | `sudo systemctl stop cron && ./healthcheck.sh; sudo systemctl start cron` | service FAIL | 1 ✅ |
| 10 | Everything fails | `DISK_MAX_PCT=0 MEM_MIN_PCT=101 CHECK_URL=http://localhost:9 CHECK_SERVICE=nope ./healthcheck.sh` | 4 FAIL, script finishes | 1 ✅ |
| 11 | Help | `./healthcheck.sh --help` | usage text | 0 ✅ |
| 12 | Bad option | `./healthcheck.sh --banana` | error + usage | 2 ✅ |

Port 9 on localhost has nothing listening, so the connection is refused immediately.

### Log file

```bash
tail -5 healthcheck.log && grep -c FAIL healthcheck.log
```

| Part | Meaning |
|---|---|
| `tail -5` | Last 5 timestamped lines |
| `grep -c FAIL` | Number of FAIL lines across all runs |

## Full script

```bash
#!/usr/bin/env bash
#
# healthcheck.sh - check disk, memory, a URL and a service.
# Exits 0 when every check passes, 1 when any check fails.
#
# Usage: ./healthcheck.sh
# Config (environment variables, all optional):
#   DISK_PATH        filesystem to check          (default: /)
#   DISK_MAX_PCT     max disk usage %             (default: 80)
#   MEM_MIN_PCT      min available memory %       (default: 10)
#   CHECK_URL        URL that must return 2xx/3xx (default: https://example.com)
#   CHECK_SERVICE    systemd service to check     (default: cron)
#   LOG_FILE         where to append logs         (default: ./healthcheck.log)

set -euo pipefail

# ---- configuration ----
DISK_PATH="${DISK_PATH:-/}"
DISK_MAX_PCT="${DISK_MAX_PCT:-80}"
MEM_MIN_PCT="${MEM_MIN_PCT:-10}"
CHECK_URL="${CHECK_URL:-https://example.com}"
CHECK_SERVICE="${CHECK_SERVICE:-cron}"
LOG_FILE="${LOG_FILE:-./healthcheck.log}"

# ---- counters ----
passed=0
failed=0

# ---- logging ----
log() {
  local level="$1"
  shift
  printf '%s [%-4s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*" | tee -a "$LOG_FILE"
}

pass() {
  log OK "$*"
  passed=$(( passed + 1 ))
}

fail() {
  log FAIL "$*" >&2
  failed=$(( failed + 1 ))
}

# ---- checks ----
check_disk() {
  local used
  if ! used=$(df -P "$DISK_PATH" 2>/dev/null | awk 'NR==2 {gsub("%",""); print $5}'); then
    fail "disk: cannot read usage for ${DISK_PATH}"
    return
  fi

  if [[ -z $used ]]; then
    fail "disk: no usage data for ${DISK_PATH}"
  elif (( used > DISK_MAX_PCT )); then
    fail "disk: ${DISK_PATH} is ${used}% used (limit ${DISK_MAX_PCT}%)"
  else
    pass "disk: ${DISK_PATH} is ${used}% used (limit ${DISK_MAX_PCT}%)"
  fi
}

check_memory() {
  local avail_pct
  if ! avail_pct=$(free -m | awk '/^Mem:/ {printf "%d", $7 / $2 * 100}'); then
    fail "memory: cannot read memory usage"
    return
  fi

  if [[ -z $avail_pct ]]; then
    fail "memory: no memory data"
  elif (( avail_pct < MEM_MIN_PCT )); then
    fail "memory: only ${avail_pct}% available (min ${MEM_MIN_PCT}%)"
  else
    pass "memory: ${avail_pct}% available (min ${MEM_MIN_PCT}%)"
  fi
}

check_url() {
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$CHECK_URL" 2>/dev/null) || true

  if [[ $code =~ ^[23][0-9][0-9]$ ]]; then
    pass "url: ${CHECK_URL} returned ${code}"
  elif [[ $code == "000" || -z $code ]]; then
    fail "url: ${CHECK_URL} is unreachable"
  else
    fail "url: ${CHECK_URL} returned ${code}"
  fi
}

check_service() {
  local state
  if ! command -v systemctl >/dev/null 2>&1; then
    fail "service: systemctl not available, cannot check ${CHECK_SERVICE}"
    return
  fi

  state=$(systemctl is-active "$CHECK_SERVICE" 2>/dev/null) || true

  if [[ $state == "active" ]]; then
    pass "service: ${CHECK_SERVICE} is active"
  else
    fail "service: ${CHECK_SERVICE} is ${state:-unknown}"
  fi
}

usage() {
  cat <<'EOF'
Usage: ./healthcheck.sh [-h|--help]

Checks disk, memory, a URL and a systemd service.
Exit code: 0 = all checks passed, 1 = at least one check failed, 2 = bad usage.

Configure with environment variables:
  DISK_PATH=/       DISK_MAX_PCT=80    MEM_MIN_PCT=10
  CHECK_URL=https://example.com        CHECK_SERVICE=cron
  LOG_FILE=./healthcheck.log

Example:
  DISK_MAX_PCT=90 CHECK_SERVICE=nginx ./healthcheck.sh
EOF
}
# ---- main ----
main() {
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    "") ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  log INFO "Health check started on $(hostname)"

  check_disk
  check_memory
  check_url
  check_service

  if (( failed > 0 )); then
    log FAIL "Summary: ${passed} passed, ${failed} failed"
    exit 1
  fi

  log INFO "Summary: ${passed} passed, ${failed} failed - all checks OK"
  exit 0
}


main "$@"
```

## Lessons from the lab

| Lesson | Detail |
|---|---|
| Test the boundaries | `DISK_MAX_PCT=1` with 1% used passed — equal isn't "above"; test equal, just above, just below |
| A check must never crash the script | `\|\| true` and `if ! var=$(…)` turn failures into FAIL lines instead of `set -e` exits |
| `local var` then assign | Keeps the command's exit code (SC2155) |
| Count with `$(( x + 1 ))` | `(( x++ ))` returns 1 when x is 0 and stops a `set -e` script |
| Errors to stderr | `>&2` keeps FAIL lines visible when output is hidden |
| Exit codes are the API | 0 / 1 / 2 is what cron, CI and pipelines read |
| Test with controlled inputs | Local web server and a 10 MB tmpfs make failures predictable |

## How I'll reuse it

| Day | Use |
|---|---|
| 5 — break-fix drill | Run it first to point at the fault (service stopped, full disk) |
| 8 — CI | ShellCheck it in the pipeline |
| 13 — CD | Same idea as the post-deploy smoke test on `/health` |

