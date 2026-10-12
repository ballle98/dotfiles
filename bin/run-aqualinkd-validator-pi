#!/usr/bin/env bash
set -euo pipefail

PI_HOST="${1:-pi@pi}"
AQUALINKD_DIR="${2:-$HOME/git/AqualinkD}"
VALIDATOR_DIR="${3:-$HOME/git/aqualinkd-validator}"
PDA_SUITE="${4:-pda-live-fast}"
PDA_TEST_DEVICES="${5:-}"
SUT_PROFILE="${6:-staged}"

REMOTE_BINARY="/tmp/aqualinkd"
REMOTE_CONFIG="/tmp/aqualinkd.conf"
REMOTE_VALIDATOR_SOURCE="/tmp/aqualinkd-validator-src"
REMOTE_ARTIFACTS="/tmp/aqualinkd-validator-artifacts"
VALIDATOR_IMAGE="aqualinkd-validator:dev"
CONTAINER_NAME="aqualinkd-validator-live-panel"

if [ -n "$PDA_TEST_DEVICES" ] &&
   [[ ! "$PDA_TEST_DEVICES" =~ ^[A-Za-z0-9_]+(,[A-Za-z0-9_]+)*$ ]]; then
  echo "ERROR: PDA test devices must be comma-separated IDs without spaces" >&2
  exit 1
fi

case "$PDA_SUITE" in
  pda-live-fast|pda-live-long|pda-live-simulator|pda-live-simulator-menu-walk) ;;
  *)
    echo "ERROR: unsupported Pi PDA suite: $PDA_SUITE" >&2
    exit 1
    ;;
esac

case "$SUT_PROFILE" in
  staged|installed) ;;
  *)
    echo "ERROR: SUT profile must be staged or installed" >&2
    exit 1
    ;;
esac

if [ "$PDA_SUITE" = "pda-live-fast" ] && [ -n "$PDA_TEST_DEVICES" ]; then
  echo "ERROR: PDA device restrictions are only used by pda-live-long" >&2
  exit 1
fi

if [ ! -f "$VALIDATOR_DIR/Dockerfile" ] ||
   [ ! -d "$VALIDATOR_DIR/src/aqualinkd_validator" ]; then
  echo "ERROR: validator checkout not found: $VALIDATOR_DIR" >&2
  exit 1
fi

VALIDATOR_COMMIT="$(git -C "$VALIDATOR_DIR" rev-parse HEAD)"

if [ "$SUT_PROFILE" = "staged" ]; then
  if [ ! -d "$AQUALINKD_DIR/.git" ] &&
     ! git -C "$AQUALINKD_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    echo "ERROR: AqualinkD checkout not found: $AQUALINKD_DIR" >&2
    exit 1
  fi
  AQUALINKD_COMMIT="$(git -C "$AQUALINKD_DIR" rev-parse HEAD)"
  AQUALINKD_BRANCH="$(git -C "$AQUALINKD_DIR" branch --show-current)"
  if [ -z "$AQUALINKD_BRANCH" ]; then
    AQUALINKD_BRANCH="detached"
  fi
  if [ -n "$(git -C "$AQUALINKD_DIR" status --porcelain)" ]; then
    AQUALINKD_LABEL="${AQUALINKD_BRANCH}-dirty"
  else
    AQUALINKD_LABEL="$AQUALINKD_BRANCH"
  fi
else
  AQUALINKD_COMMIT="not-recorded"
  AQUALINKD_BRANCH="installed"
  AQUALINKD_LABEL="installed"
fi

if [ -n "$(git -C "$VALIDATOR_DIR" status --porcelain)" ]; then
  VALIDATOR_REF="${VALIDATOR_COMMIT}-dirty"
else
  VALIDATOR_REF="$VALIDATOR_COMMIT"
fi

echo "Staging validator source"
echo "  Target:    $PI_HOST"
echo "  Validator: $VALIDATOR_REF"
echo "  SUT:       $SUT_PROFILE"
if [ "$SUT_PROFILE" = "staged" ]; then
  echo "  AqualinkD: $AQUALINKD_BRANCH ($AQUALINKD_COMMIT)"
else
  echo "  AqualinkD: $PI_HOST:/usr/local/bin/aqualinkd"
fi
echo "  Suite:     $PDA_SUITE"
if [ "$PDA_SUITE" = "pda-live-long" ]; then
  echo "  Devices:   ${PDA_TEST_DEVICES:-all discovered switches}"
elif [[ "$PDA_SUITE" == pda-live-simulator* ]]; then
  echo "  Devices:   none (read-only simulator transport)"
else
  echo "  Devices:   suite-defined filter pump and optional heater"
fi
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
  "$REMOTE_ARTIFACTS" \
  "$VALIDATOR_IMAGE" \
  "$CONTAINER_NAME" \
  "$AQUALINKD_LABEL" \
  "$AQUALINKD_COMMIT" \
  "$AQUALINKD_BRANCH" \
  "$PDA_SUITE" \
  "$SUT_PROFILE" \
  "$PDA_TEST_DEVICES" <<'REMOTE_RUN'
set -euo pipefail

REMOTE_BINARY="$1"
REMOTE_CONFIG="$2"
REMOTE_ARTIFACTS="$3"
VALIDATOR_IMAGE="$4"
CONTAINER_NAME="$5"
AQUALINKD_LABEL="$6"
AQUALINKD_COMMIT="$7"
AQUALINKD_BRANCH="$8"
PDA_SUITE="$9"
SUT_PROFILE="${10}"
PDA_TEST_DEVICES="${11:-}"

PDA_DEVICE_ARGS=()
if [ -n "$PDA_TEST_DEVICES" ]; then
  IFS=',' read -r -a selected_devices <<<"$PDA_TEST_DEVICES"
  for device in "${selected_devices[@]}"; do
    device="${device#"${device%%[![:space:]]*}"}"
    device="${device%"${device##*[![:space:]]}"}"
    if [[ ! "$device" =~ ^[A-Za-z0-9_]+$ ]]; then
      echo "ERROR: unsafe PDA test device ID: $device" >&2
      exit 1
    fi
    PDA_DEVICE_ARGS+=(--pda-test-device "$device")
  done
fi

case "$SUT_PROFILE" in
  staged)
    SUT_BINARY="$REMOTE_BINARY"
    SUT_CONFIG="$REMOTE_CONFIG"
    SOURCE_ARGS=(
      --source-commit "$AQUALINKD_COMMIT"
      --source-branch "$AQUALINKD_BRANCH"
    )
    ;;
  installed)
    SUT_BINARY="/usr/local/bin/aqualinkd"
    SUT_CONFIG="/etc/aqualinkd.conf"
    AQUALINKD_LABEL="installed"
    SOURCE_ARGS=()
    ;;
esac
CONTAINER_BINARY="/usr/local/bin/aqualinkd"
CONTAINER_CONFIG="/etc/aqualinkd.conf"

for required_path in "$SUT_BINARY" "$SUT_CONFIG"; do
  if [ ! -e "$required_path" ]; then
    echo "ERROR: SUT path is missing: $required_path" >&2
    exit 1
  fi
done

SERIAL_DEVICE="$(
  sed -n \
    's/^[[:space:]]*serial_port[[:space:]]*=[[:space:]]*//p' \
    "$SUT_CONFIG" |
    tail -1 |
    sed -e 's/[[:space:]]*$//' -e 's/^["'\'']//' -e 's/["'\'']$//'
)"

case "$SERIAL_DEVICE" in
  /dev/*) ;;
  *)
    echo "ERROR: unsafe or missing serial_port in $SUT_CONFIG" >&2
    exit 1
    ;;
esac

if [ ! -c "$SERIAL_DEVICE" ]; then
  echo "ERROR: serial endpoint is not a character device: $SERIAL_DEVICE" >&2
  exit 1
fi

SUT_WEB="$(
  sed -n \
    's/^[[:space:]]*web_directory[[:space:]]*=[[:space:]]*//p' \
    "$SUT_CONFIG" |
    tail -1 |
    sed -e 's/[[:space:]]*$//' -e 's/^["'\'']//' -e 's/["'\'']$//'
)"
SUT_WEB="${SUT_WEB%/}"

case "$SUT_WEB" in
  /|/proc|/proc/*|/sys|/sys/*|/dev|/dev/*)
    echo "ERROR: unsafe web_directory in $SUT_CONFIG: $SUT_WEB" >&2
    exit 1
    ;;
  /*) ;;
  *)
    echo "ERROR: unsafe or missing web_directory in $SUT_CONFIG" >&2
    exit 1
    ;;
esac
if [ ! -d "$SUT_WEB" ]; then
  echo "ERROR: web_directory is not a directory: $SUT_WEB" >&2
  exit 1
fi

PANEL_TIMEZONE="$(
  timedatectl show --property=Timezone --value 2>/dev/null ||
    cat /etc/timezone
)"
if [[ ! "$PANEL_TIMEZONE" =~ ^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$ ]]; then
  echo "ERROR: could not determine a safe IANA timezone: $PANEL_TIMEZONE" >&2
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
if [ "$PDA_SUITE" = "pda-live-long" ] &&
   [ -z "$PDA_TEST_DEVICES" ]; then
  echo "  WARNING: this suite changes every discovered switch and heater settings"
elif [ "$PDA_SUITE" = "pda-live-long" ]; then
  echo "  WARNING: this suite changes the restricted switches and heater settings"
elif [[ "$PDA_SUITE" == pda-live-simulator* ]]; then
  echo "  Access:    read-only AquaPDA simulator transport"
else
  echo "  WARNING: this suite changes filter-pump and heater settings"
fi
echo "  SUT:       $SUT_PROFILE"
echo "  Suite:     $PDA_SUITE"
echo "  Serial:    $SERIAL_DEVICE"
echo "  Binary:    $SUT_BINARY -> $CONTAINER_BINARY"
echo "  Config:    $SUT_CONFIG -> $CONTAINER_CONFIG"
echo "  Timezone:  $PANEL_TIMEZONE"
echo "  Web:       $SUT_WEB"
echo "  Artifacts: $REMOTE_ARTIFACTS"

if [[ "$PDA_SUITE" == pda-live-simulator* ]]; then
  PANEL_ACCESS_ARG="--panel-read-only"
else
  PANEL_ACCESS_ARG="--panel-read-write"
fi

sudo docker run --rm \
  --name "$CONTAINER_NAME" \
  --env "TZ=$PANEL_TIMEZONE" \
  --device "$SERIAL_DEVICE:$SERIAL_DEVICE" \
  --mount \
    "type=bind,source=$SUT_BINARY,target=$CONTAINER_BINARY,readonly" \
  --mount \
    "type=bind,source=$SUT_CONFIG,target=$CONTAINER_CONFIG,readonly" \
  --mount \
    "type=bind,source=$SUT_WEB,target=$SUT_WEB" \
  --mount \
    "type=bind,source=$REMOTE_ARTIFACTS,target=$REMOTE_ARTIFACTS" \
  "$VALIDATOR_IMAGE" run \
    "$PANEL_ACCESS_ARG" \
    "${PDA_DEVICE_ARGS[@]}" \
    "${SOURCE_ARGS[@]}" \
    --label "$AQUALINKD_LABEL" \
    "$PDA_SUITE"

echo
echo "Artifacts are available at $REMOTE_ARTIFACTS"
REMOTE_RUN
