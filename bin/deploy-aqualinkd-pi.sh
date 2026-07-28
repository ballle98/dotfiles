#!/usr/bin/env bash
set -euo pipefail

PI_HOST="${1:-pi@pi}"
PROJECT_DIR="${2:-$HOME/git/AqualinkD}"

LOCAL_BINARY="$PROJECT_DIR/release/aqualinkd-arm64"
LOCAL_CONFIG="$PROJECT_DIR/release/aqualinkd.conf"
LOCAL_WEB="$PROJECT_DIR/web"

REMOTE_BINARY="/tmp/aqualinkd"
REMOTE_CONFIG="/tmp/aqualinkd.conf"
REMOTE_WEB="/tmp/aqualinkd-web"

if [ ! -f "$LOCAL_BINARY" ]; then
  echo "ERROR: ARM64 binary not found: $LOCAL_BINARY" >&2
  exit 1
fi

if [ ! -f "$LOCAL_CONFIG" ]; then
  echo "ERROR: Configuration not found: $LOCAL_CONFIG" >&2
  exit 1
fi

if [ ! -d "$LOCAL_WEB" ]; then
  echo "ERROR: Web directory not found: $LOCAL_WEB" >&2
  exit 1
fi

if [ ! -f "$LOCAL_WEB/config.json" ]; then
  echo "ERROR: Default web configuration not found: $LOCAL_WEB/config.json" >&2
  exit 1
fi

echo "Staging AqualinkD 3.x development files"
echo "  Target: $PI_HOST"
echo "  Binary: $REMOTE_BINARY"
echo "  Config: $REMOTE_CONFIG"
echo "  Web:    $REMOTE_WEB/"

ssh "$PI_HOST" "mkdir -p '$REMOTE_WEB'"

scp "$LOCAL_BINARY" "$PI_HOST:$REMOTE_BINARY.new"
ssh "$PI_HOST" "chmod 755 '$REMOTE_BINARY.new' && mv '$REMOTE_BINARY.new' '$REMOTE_BINARY'"

# Keep the test installation's writable web configuration between deployments.
rsync -a --delete --exclude='config.json' \
  "$LOCAL_WEB/" \
  "$PI_HOST:$REMOTE_WEB/"

if ! ssh "$PI_HOST" "test -f '$REMOTE_WEB/config.json'"; then
  scp "$LOCAL_WEB/config.json" "$PI_HOST:$REMOTE_WEB/config.json"
fi

# Use the configuration shipped with this checkout, then point it at the
# separately staged 3.x web files.
if ! ssh "$PI_HOST" "test -f '$REMOTE_CONFIG'"; then
  scp "$LOCAL_CONFIG" "$PI_HOST:$REMOTE_CONFIG"
fi

ssh "$PI_HOST" bash -s -- "$REMOTE_CONFIG" "$REMOTE_WEB" <<'REMOTE_SCRIPT'
set -euo pipefail

REMOTE_CONFIG="$1"
REMOTE_WEB="$2"

if grep -Eq '^[[:space:]]*web_directory[[:space:]]*=' "$REMOTE_CONFIG"; then
  sed -i -E \
    "s|^[[:space:]]*web_directory[[:space:]]*=.*$|web_directory=$REMOTE_WEB/|" \
    "$REMOTE_CONFIG"
else
  printf '\nweb_directory=%s/\n' "$REMOTE_WEB" >> "$REMOTE_CONFIG"
fi

chmod 600 "$REMOTE_CONFIG"
REMOTE_SCRIPT

ssh "$PI_HOST" "file '$REMOTE_BINARY' && ldd '$REMOTE_BINARY'"

echo
echo "AqualinkD 3.x staging is ready."
echo "Run with: sudo $REMOTE_BINARY -d -v -c $REMOTE_CONFIG"
