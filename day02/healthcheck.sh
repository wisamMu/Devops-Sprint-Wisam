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