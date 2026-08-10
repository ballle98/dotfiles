#!/usr/bin/env bash
set -euo pipefail

PI_HOST="${1:-pi@pi}"
REMOTE_BINARY="/tmp/aqualinkd"
REMOTE_CONFIG="/tmp/aqualinkd.conf"

existing_pids="$({
  ssh "$PI_HOST" bash -s -- "$REMOTE_BINARY" "$REMOTE_CONFIG" <<'REMOTE_PREFLIGHT'
REMOTE_BINARY="$1"
REMOTE_CONFIG="$2"
DEBUG_PATTERN="^${REMOTE_BINARY} -d -v -c ${REMOTE_CONFIG}$"
pgrep -f -- "$DEBUG_PATTERN" || true
REMOTE_PREFLIGHT
} 2>/dev/null)"

if [ -n "$existing_pids" ]; then
  echo "ERROR: staged AqualinkD debug process is already running: $existing_pids" >&2
  echo "Terminate its VS Code task or run the cleanup task before starting another." >&2
  exit 2
fi

restore_pi() {
  status=$?
  trap - EXIT HUP INT TERM
  set +e

  echo
  echo "Stopping staged AqualinkD and restoring the installed service"
  ssh "$PI_HOST" bash -s -- "$REMOTE_BINARY" "$REMOTE_CONFIG" <<'REMOTE_CLEANUP'
set -u

REMOTE_BINARY="$1"
REMOTE_CONFIG="$2"
DEBUG_PATTERN="^${REMOTE_BINARY} -d -v -c ${REMOTE_CONFIG}$"

sudo pkill -TERM -f -- "$DEBUG_PATTERN" 2>/dev/null || true
for _ in {1..20}; do
  if ! pgrep -f -- "$DEBUG_PATTERN" >/dev/null; then
    break
  fi
  sleep 0.25
done

if pgrep -f -- "$DEBUG_PATTERN" >/dev/null; then
  echo "WARNING: staged AqualinkD did not stop after SIGTERM; using SIGKILL" >&2
  sudo pkill -KILL -f -- "$DEBUG_PATTERN" 2>/dev/null || true
  for _ in {1..8}; do
    if ! pgrep -f -- "$DEBUG_PATTERN" >/dev/null; then
      break
    fi
    sleep 0.25
  done
fi

if pgrep -f -- "$DEBUG_PATTERN" >/dev/null; then
  echo "ERROR: staged AqualinkD is still running after SIGKILL" >&2
  cleanup_status=1
else
  cleanup_status=0
fi

sudo systemctl reset-failed aqualinkd
sudo systemctl start aqualinkd
service_status=$?
if [ "$service_status" -eq 0 ]; then
  sudo systemctl is-active --quiet aqualinkd
  service_status=$?
fi

if [ "$cleanup_status" -ne 0 ] || [ "$service_status" -ne 0 ]; then
  echo "ERROR: debug cleanup did not restore a healthy AqualinkD service" >&2
  sudo systemctl status aqualinkd --no-pager -l >&2 || true
  exit 1
fi

echo "Installed AqualinkD service is active"
REMOTE_CLEANUP
  cleanup_status=$?

  if [ "$cleanup_status" -ne 0 ]; then
    status=1
  fi
  exit "$status"
}

trap restore_pi EXIT HUP INT TERM

ssh "$PI_HOST" bash -s -- "$REMOTE_BINARY" "$REMOTE_CONFIG" <<'REMOTE_RUN'
set -euo pipefail

REMOTE_BINARY="$1"
REMOTE_CONFIG="$2"
LOG_FILE="/tmp/aqualinkd-debug-$(date +%Y%m%d-%H%M%S).log"

for required_path in "$REMOTE_BINARY" "$REMOTE_CONFIG"; do
  if [ ! -e "$required_path" ]; then
    echo "ERROR: staged path is missing: $required_path" >&2
    exit 1
  fi
done

echo "Stopping the installed AqualinkD service"
sudo systemctl stop aqualinkd

echo "Running $REMOTE_BINARY with $REMOTE_CONFIG"
echo "Debug log: $LOG_FILE"
sudo "$REMOTE_BINARY" -d -v -c "$REMOTE_CONFIG" 2>&1 | tee "$LOG_FILE"
REMOTE_RUN
