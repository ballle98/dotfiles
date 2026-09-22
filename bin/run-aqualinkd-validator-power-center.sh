#!/usr/bin/env bash
set -euo pipefail

SUITE="${1:-pda-power-center-fast}"
AQUALINKD_DIR="${2:-$HOME/git/AqualinkD}"
VALIDATOR_DIR="${3:-$HOME/git/aqualinkd-validator}"
WINE_PREFIX="${4:-$HOME/.wine-aqualink}"

AQUALINKD_BINARY="$AQUALINKD_DIR/release/aqualinkd-amd64"
VALIDATOR="$VALIDATOR_DIR/.venv/bin/aqualinkd-validator"
CONFIG_TEMPLATE="$VALIDATOR_DIR/examples/aqualinkd-wsl.conf"
SITE_TEMPLATE="$VALIDATOR_DIR/examples/aqualinkd-validator-wsl.yaml"
POWER_CENTER_HELPER="$VALIDATOR_DIR/contrib/power-center-helper/build/pwrcntr-control.exe"
RUNTIME_CONFIG="/tmp/aqualinkd-wsl.conf"
RUNTIME_SITE="/tmp/aqualinkd-validator.yaml"
PANEL_LINK="/tmp/jandy-panel"
AQUALINKD_LINK="/tmp/aqualinkd-panel"
COM_LINK="$WINE_PREFIX/dosdevices/com3"
ARTIFACTS="$VALIDATOR_DIR/artifacts"

case "$SUITE" in
  pda-power-center-fast|pda-power-center-full|rs-fast|rs-full)
    POWER_CENTER_MODEL="B29231 (16 Combo)"
    ;;
  *)
    echo "ERROR: unsupported Power Center suite: $SUITE" >&2
    exit 1
    ;;
esac

for command in awk readlink socat sudo wine; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "ERROR: required command is not installed: $command" >&2
    exit 1
  fi
done

for required_file in \
  "$AQUALINKD_BINARY" \
  "$VALIDATOR" \
  "$CONFIG_TEMPLATE" \
  "$SITE_TEMPLATE" \
  "$POWER_CENTER_HELPER"; do
  if [ ! -f "$required_file" ]; then
    echo "ERROR: required file is missing: $required_file" >&2
    exit 1
  fi
done

for required_directory in "$AQUALINKD_DIR/web" "$WINE_PREFIX"; do
  if [ ! -d "$required_directory" ]; then
    echo "ERROR: required directory is missing: $required_directory" >&2
    exit 1
  fi
done

for runtime_file in "$RUNTIME_CONFIG" "$RUNTIME_SITE"; do
  if [ -L "$runtime_file" ]; then
    echo "ERROR: refusing to replace symlink: $runtime_file" >&2
    exit 1
  fi
  if [ -e "$runtime_file" ] && [ ! -O "$runtime_file" ]; then
    echo "ERROR: runtime file is not owned by the current user: $runtime_file" >&2
    exit 1
  fi
done

for serial_link in "$PANEL_LINK" "$AQUALINKD_LINK"; do
  if [ -e "$serial_link" ] || [ -L "$serial_link" ]; then
    echo "ERROR: serial link already exists: $serial_link" >&2
    exit 1
  fi
done

if [ -e "$COM_LINK" ] && [ ! -L "$COM_LINK" ]; then
  echo "ERROR: Wine COM3 path is not a symlink: $COM_LINK" >&2
  exit 1
fi

if [ -e "$ARTIFACTS" ] && [ ! -d "$ARTIFACTS" ]; then
  echo "ERROR: artifact path is not a directory: $ARTIFACTS" >&2
  exit 1
fi
mkdir -p "$ARTIFACTS"
if [ ! -O "$ARTIFACTS" ]; then
  echo "ERROR: artifact directory is not owned by the current user: $ARTIFACTS" >&2
  exit 1
fi

sudo -n true

SOCAT_PID=""
SOCAT_LOG="$(mktemp /tmp/aqualinkd-validator-socat.XXXXXX.log)"
COM_CHANGED=false
HAD_COM_LINK=false
ORIGINAL_COM_TARGET=""
if [ -L "$COM_LINK" ]; then
  HAD_COM_LINK=true
  ORIGINAL_COM_TARGET="$(readlink "$COM_LINK")"
fi

cleanup() {
  status=$?
  trap - EXIT HUP INT TERM

  if [ -n "$SOCAT_PID" ] && kill -0 "$SOCAT_PID" 2>/dev/null; then
    kill -TERM "$SOCAT_PID" 2>/dev/null || true
    wait "$SOCAT_PID" 2>/dev/null || true
  fi

  if [ "$COM_CHANGED" = true ]; then
    if [ "$HAD_COM_LINK" = true ]; then
      env WINEPREFIX="$WINE_PREFIX" wine reg add \
        'HKLM\Software\Wine\Ports' /v COM3 /d "$ORIGINAL_COM_TARGET" /f \
        >/dev/null 2>&1 || status=1
    else
      env WINEPREFIX="$WINE_PREFIX" wine reg delete \
        'HKLM\Software\Wine\Ports' /v COM3 /f \
        >/dev/null 2>&1 || true
    fi
    if [ -L "$COM_LINK" ]; then
      unlink "$COM_LINK"
    fi
    if [ "$HAD_COM_LINK" = true ]; then
      ln -s "$ORIGINAL_COM_TARGET" "$COM_LINK"
    fi
  fi

  sudo -n chown -R "$(id -u):$(id -g)" "$ARTIFACTS" || status=1
  if [ -f "$SOCAT_LOG" ] && [ -O "$SOCAT_LOG" ]; then
    unlink "$SOCAT_LOG"
  fi
  exit "$status"
}
trap cleanup EXIT HUP INT TERM

socat \
  PTY,link="$PANEL_LINK",raw,echo=0,mode=666 \
  PTY,link="$AQUALINKD_LINK",raw,echo=0,mode=666 \
  >"$SOCAT_LOG" 2>&1 &
SOCAT_PID=$!

for _ in {1..100}; do
  if [ -L "$PANEL_LINK" ] && [ -L "$AQUALINKD_LINK" ]; then
    break
  fi
  if ! kill -0 "$SOCAT_PID" 2>/dev/null; then
    echo "ERROR: socat exited before creating the PTY pair" >&2
    sed -n '1,120p' "$SOCAT_LOG" >&2
    exit 1
  fi
  sleep 0.05
done

if [ ! -L "$PANEL_LINK" ] || [ ! -L "$AQUALINKD_LINK" ]; then
  echo "ERROR: timed out waiting for the socat PTY pair" >&2
  exit 1
fi

PANEL_TTY="$(readlink -f "$PANEL_LINK")"
AQUALINKD_TTY="$(readlink -f "$AQUALINKD_LINK")"
if [ ! -c "$PANEL_TTY" ] || [ ! -c "$AQUALINKD_TTY" ]; then
  echo "ERROR: socat did not create character-device endpoints" >&2
  exit 1
fi

umask 077
awk \
  -v serial_port="$AQUALINKD_TTY" \
  -v web_directory="$AQUALINKD_DIR/web/" \
  '
    /^[[:space:]]*serial_port[[:space:]]*=/ {
      print "serial_port = " serial_port
      next
    }
    /^[[:space:]]*web_directory[[:space:]]*=/ {
      print "web_directory = " web_directory
      next
    }
    { print }
  ' "$CONFIG_TEMPLATE" >"$RUNTIME_CONFIG"

awk \
  -v helper="$POWER_CENTER_HELPER" \
  -v wine_prefix="$WINE_PREFIX" \
  -v model="$POWER_CENTER_MODEL" \
  '
    /^[[:space:]]*helper:/ {
      print "  helper: " helper
      next
    }
    /^[[:space:]]*wine_prefix:/ {
      print "  wine_prefix: " wine_prefix
      next
    }
    /^[[:space:]]*model:/ {
      print "  model: \"" model "\""
      next
    }
    { print }
  ' "$SITE_TEMPLATE" >"$RUNTIME_SITE"

COM_CHANGED=true
env WINEPREFIX="$WINE_PREFIX" wine reg add \
  'HKLM\Software\Wine\Ports' /v COM3 /d "$PANEL_TTY" /f >/dev/null
if [ -L "$COM_LINK" ]; then
  unlink "$COM_LINK"
fi
ln -s "$PANEL_TTY" "$COM_LINK"

echo "Running $SUITE with $POWER_CENTER_MODEL"
echo "  Power Center: $PANEL_TTY (Wine COM3)"
echo "  AqualinkD:    $AQUALINKD_TTY"
echo "  Config:       $RUNTIME_CONFIG"
echo "  Site profile: $RUNTIME_SITE"
echo "  Artifacts:    $ARTIFACTS"

set +e
sudo -n "$VALIDATOR" run \
  --mode jandy-power-center \
  --power-center-display headless \
  --panel-read-write \
  --aqualinkd "$AQUALINKD_BINARY" \
  --config "$RUNTIME_CONFIG" \
  --site-config "$RUNTIME_SITE" \
  --artifacts "$ARTIFACTS" \
  --label "vscode-$SUITE" \
  "$SUITE"
status=$?
set -e
exit "$status"
