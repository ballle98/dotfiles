#!/usr/bin/env bash
set -euo pipefail

PI_HOST="${1:-pi@pi}"
AQUALINKD_DIR="${2:-$HOME/git/AqualinkD}"
VALIDATOR_DIR="${3:-$HOME/git/aqualinkd-validator}"
RUN_DURATION="${4:-600}"

REMOTE_BINARY="/tmp/aqualinkd"
REMOTE_CONFIG="/tmp/aqualinkd.conf"
REMOTE_WEB="/tmp/aqualinkd-web"
REMOTE_VALIDATOR_SOURCE="/tmp/aqualinkd-validator-src"
REMOTE_ARTIFACTS="/tmp/aqualinkd-validator-artifacts"
VALIDATOR_IMAGE="aqualinkd-validator:dev"
CONTAINER_NAME="aqualinkd-validator-live-panel"

if [[ ! "$RUN_DURATION" =~ ^[0-9]+([.][0-9]+)?$ ]] ||
   ! awk -v duration="$RUN_DURATION" 'BEGIN { exit !(duration > 0) }'; then
  echo "ERROR: duration must be a positive number: $RUN_DURATION" >&2
  exit 1
fi

if [ ! -d "$AQUALINKD_DIR/.git" ] &&
   ! git -C "$AQUALINKD_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: AqualinkD checkout not found: $AQUALINKD_DIR" >&2
  exit 1
fi

if [ ! -f "$VALIDATOR_DIR/Dockerfile" ] ||
   [ ! -d "$VALIDATOR_DIR/src/aqualinkd_validator" ]; then
  echo "ERROR: validator checkout not found: $VALIDATOR_DIR" >&2
  exit 1
fi

AQUALINKD_COMMIT="$(git -C "$AQUALINKD_DIR" rev-parse HEAD)"
AQUALINKD_BRANCH="$(git -C "$AQUALINKD_DIR" branch --show-current)"
VALIDATOR_COMMIT="$(git -C "$VALIDATOR_DIR" rev-parse HEAD)"

if [ -z "$AQUALINKD_BRANCH" ]; then
  AQUALINKD_BRANCH="detached"
fi

if [ -n "$(git -C "$AQUALINKD_DIR" status --porcelain)" ]; then
  AQUALINKD_LABEL="${AQUALINKD_BRANCH}-dirty"
else
  AQUALINKD_LABEL="$AQUALINKD_BRANCH"
fi

if [ -n "$(git -C "$VALIDATOR_DIR" status --porcelain)" ]; then
  VALIDATOR_REF="${VALIDATOR_COMMIT}-dirty"
else
  VALIDATOR_REF="$VALIDATOR_COMMIT"
fi

echo "Staging validator source"
echo "  Target:    $PI_HOST"
echo "  Validator: $VALIDATOR_REF"
echo "  AqualinkD: $AQUALINKD_BRANCH ($AQUALINKD_COMMIT)"
echo "  Duration:  $RUN_DURATION seconds"
echo "  Artifacts: $PI_HOST:$REMOTE_ARTIFACTS"

ssh "$PI_HOST" "mkdir -p '$REMOTE_VALIDATOR_SOURCE' '$REMOTE_ARTIFACTS'"

rsync -a --delete \
  --exclude='.git/' \
  --exclude='.mypy_cache/' \
  --exclude='.pytest_cache/' \
  --exclude='.ruff_cache/' \
  --exclude='.venv/' \
  --exclude='artifacts/' \
  --exclude='__pycache__/' \
  "$VALIDATOR_DIR/" \
  "$PI_HOST:$REMOTE_VALIDATOR_SOURCE/"

ssh "$PI_HOST" bash -s -- \
  "$REMOTE_VALIDATOR_SOURCE" \
  "$VALIDATOR_IMAGE" \
  "$VALIDATOR_REF" <<'REMOTE_BUILD'
set -euo pipefail

REMOTE_VALIDATOR_SOURCE="$1"
VALIDATOR_IMAGE="$2"
VALIDATOR_REF="$3"

sudo docker build \
  --build-arg "VCS_REF=$VALIDATOR_REF" \
  --tag "$VALIDATOR_IMAGE" \
  "$REMOTE_VALIDATOR_SOURCE"
REMOTE_BUILD

ssh "$PI_HOST" bash -s -- \
  "$REMOTE_BINARY" \
  "$REMOTE_CONFIG" \
  "$REMOTE_WEB" \
  "$REMOTE_ARTIFACTS" \
  "$VALIDATOR_IMAGE" \
  "$CONTAINER_NAME" \
  "$RUN_DURATION" \
  "$AQUALINKD_LABEL" \
  "$AQUALINKD_COMMIT" \
  "$AQUALINKD_BRANCH" <<'REMOTE_RUN'
set -euo pipefail

REMOTE_BINARY="$1"
REMOTE_CONFIG="$2"
REMOTE_WEB="$3"
REMOTE_ARTIFACTS="$4"
VALIDATOR_IMAGE="$5"
CONTAINER_NAME="$6"
RUN_DURATION="$7"
AQUALINKD_LABEL="$8"
AQUALINKD_COMMIT="$9"
AQUALINKD_BRANCH="${10}"

for required_path in \
  "$REMOTE_BINARY" \
  "$REMOTE_CONFIG" \
  "$REMOTE_WEB"; do
  if [ ! -e "$required_path" ]; then
    echo "ERROR: staged path is missing: $required_path" >&2
    exit 1
  fi
done

SERIAL_DEVICE="$(
  sed -n \
    's/^[[:space:]]*serial_port[[:space:]]*=[[:space:]]*//p' \
    "$REMOTE_CONFIG" |
    tail -1 |
    sed -e 's/[[:space:]]*$//' -e 's/^["'\'']//' -e 's/["'\'']$//'
)"

case "$SERIAL_DEVICE" in
  /dev/*) ;;
  *)
    echo "ERROR: unsafe or missing serial_port in $REMOTE_CONFIG" >&2
    exit 1
    ;;
esac

if [ ! -c "$SERIAL_DEVICE" ]; then
  echo "ERROR: serial endpoint is not a character device: $SERIAL_DEVICE" >&2
  exit 1
fi

restore_service() {
  status=$?
  trap - EXIT HUP INT TERM
  sudo docker rm --force "$CONTAINER_NAME" >/dev/null 2>&1 || true
  sudo chown -R "$(id -u):$(id -g)" "$REMOTE_ARTIFACTS" || true
  if ! sudo systemctl start aqualinkd; then
    echo "ERROR: failed to restore the installed AqualinkD service" >&2
    status=1
  fi
  exit "$status"
}
trap restore_service EXIT HUP INT TERM

echo "Stopping the installed AqualinkD service"
sudo systemctl stop aqualinkd

for _ in {1..20}; do
  if ! pgrep -x aqualinkd >/dev/null; then
    break
  fi
  sleep 0.25
done

if pgrep -x aqualinkd >/dev/null; then
  echo "ERROR: an AqualinkD process is still running; refusing serial access" >&2
  exit 1
fi

sudo docker rm --force "$CONTAINER_NAME" >/dev/null 2>&1 || true

echo "Running validator container"
echo "  Serial:    $SERIAL_DEVICE"
echo "  Binary:    $REMOTE_BINARY"
echo "  Config:    $REMOTE_CONFIG"
echo "  Web:       $REMOTE_WEB"
echo "  Artifacts: $REMOTE_ARTIFACTS"

sudo docker run --rm \
  --name "$CONTAINER_NAME" \
  --network host \
  --device "$SERIAL_DEVICE:$SERIAL_DEVICE" \
  --mount \
    "type=bind,source=$REMOTE_BINARY,target=$REMOTE_BINARY,readonly" \
  --mount \
    "type=bind,source=$REMOTE_CONFIG,target=$REMOTE_CONFIG,readonly" \
  --mount \
    "type=bind,source=$REMOTE_WEB,target=$REMOTE_WEB" \
  --mount \
    "type=bind,source=$REMOTE_ARTIFACTS,target=/artifacts" \
  "$VALIDATOR_IMAGE" run \
    --mode live-panel \
    --allow-live-panel \
    --serial-device "$SERIAL_DEVICE" \
    --aqualinkd "$REMOTE_BINARY" \
    --source-commit "$AQUALINKD_COMMIT" \
    --source-branch "$AQUALINKD_BRANCH" \
    --workdir /tmp \
    --config "$REMOTE_CONFIG" \
    --duration "$RUN_DURATION" \
    --label "$AQUALINKD_LABEL" \
    --artifacts /artifacts

echo
echo "Artifacts are available at $REMOTE_ARTIFACTS"
REMOTE_RUN
