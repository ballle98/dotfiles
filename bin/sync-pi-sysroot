#!/usr/bin/env bash
set -euo pipefail

PI_HOST="${1:-pi@pi}"
SYSROOT="${2:-$HOME/sysroots/pi-arm64}"

ARCH_TRIPLET="aarch64-linux-gnu"
DYNAMIC_LOADER="ld-linux-aarch64.so.1"

echo "============================================================"
echo " Raspberry Pi sysroot sync"
echo "============================================================"
echo "Target Pi:  $PI_HOST"
echo "Sysroot:    $SYSROOT"
echo "Arch:       $ARCH_TRIPLET"
echo

echo "Checking SSH connectivity..."
ssh "$PI_HOST" 'uname -m; dpkg --print-architecture; ldd --version | head -1'
echo

echo "Checking required target directories on Pi..."
ssh "$PI_HOST" "test -d /usr/include"
ssh "$PI_HOST" "test -d /usr/lib/$ARCH_TRIPLET"

if ssh "$PI_HOST" "test -e /usr/lib/$DYNAMIC_LOADER"; then
  LOADER_REMOTE="/usr/lib/$DYNAMIC_LOADER"
elif ssh "$PI_HOST" "test -e /lib/$DYNAMIC_LOADER"; then
  LOADER_REMOTE="/lib/$DYNAMIC_LOADER"
else
  echo "ERROR: Could not find dynamic loader $DYNAMIC_LOADER on target."
  echo "Checked:"
  echo "  /usr/lib/$DYNAMIC_LOADER"
  echo "  /lib/$DYNAMIC_LOADER"
  exit 1
fi

echo "Dynamic loader found at: $LOADER_REMOTE"
echo

echo "Recreating local sysroot..."
rm -rf "$SYSROOT"
mkdir -p "$SYSROOT"

echo
echo "Mirroring top-level root symlinks from Pi..."
echo "This preserves merged-/usr layout, e.g. /lib -> usr/lib."

# Mirror common top-level symlinks if present.
# We create only the symlink itself, not the target contents.
for path in /lib /bin /sbin /lib64; do
  if ssh "$PI_HOST" "test -L '$path'"; then
    target="$(ssh "$PI_HOST" "readlink '$path'")"
    name="$(basename "$path")"

    ln -sfn "$target" "$SYSROOT/$name"
    echo "  $path -> $target"
  elif ssh "$PI_HOST" "test -e '$path'"; then
    echo "  $path exists but is not a symlink; not mirroring as top-level symlink"
  else
    echo "  $path does not exist; skipping"
  fi
done

echo
echo "Creating base sysroot directories..."
mkdir -p "$SYSROOT/usr/include"
mkdir -p "$SYSROOT/usr/lib"
mkdir -p "$SYSROOT/usr/lib/$ARCH_TRIPLET"
mkdir -p "$SYSROOT/usr/share"
mkdir -p "$SYSROOT/usr/lib/pkgconfig"
mkdir -p "$SYSROOT/usr/share/pkgconfig"

echo
echo "Syncing headers: /usr/include/"
rsync -aH --delete \
  "$PI_HOST:/usr/include/" \
  "$SYSROOT/usr/include/"

echo
echo "Syncing architecture libraries: /usr/lib/$ARCH_TRIPLET/"
rsync -aH --delete \
  "$PI_HOST:/usr/lib/$ARCH_TRIPLET/" \
  "$SYSROOT/usr/lib/$ARCH_TRIPLET/"

echo
echo "Syncing dynamic loader: $LOADER_REMOTE"
rsync -aH \
  "$PI_HOST:$LOADER_REMOTE" \
  "$SYSROOT/usr/lib/"

echo
echo "Syncing pkg-config metadata if present..."

# These may or may not exist. Do not fail the whole sync if absent.
rsync -aH --delete --ignore-missing-args \
  "$PI_HOST:/usr/lib/pkgconfig/" \
  "$SYSROOT/usr/lib/pkgconfig/" || true

rsync -aH --delete --ignore-missing-args \
  "$PI_HOST:/usr/share/pkgconfig/" \
  "$SYSROOT/usr/share/pkgconfig/" || true

if ssh "$PI_HOST" "test -d /usr/lib/$ARCH_TRIPLET/pkgconfig"; then
  mkdir -p "$SYSROOT/usr/lib/$ARCH_TRIPLET/pkgconfig"
  rsync -aH --delete \
    "$PI_HOST:/usr/lib/$ARCH_TRIPLET/pkgconfig/" \
    "$SYSROOT/usr/lib/$ARCH_TRIPLET/pkgconfig/"
fi

echo
echo "Checking for libsystemd development files..."
if [ -d "$SYSROOT/usr/include/systemd" ]; then
  echo "  Found systemd headers: $SYSROOT/usr/include/systemd"
else
  echo "  WARNING: systemd headers not found."
  echo "  If AqualinkD needs AQ_MANAGER=true, run on Pi:"
  echo "    sudo apt install libsystemd-dev"
  echo "  Then rerun this script."
fi

if ls "$SYSROOT/usr/lib/$ARCH_TRIPLET"/libsystemd* >/dev/null 2>&1; then
  echo "  Found libsystemd libraries:"
  ls -l "$SYSROOT/usr/lib/$ARCH_TRIPLET"/libsystemd*
else
  echo "  WARNING: libsystemd libraries not found in $SYSROOT/usr/lib/$ARCH_TRIPLET"
fi

echo
echo "Verifying dynamic loader through sysroot /lib path..."
if [ -e "$SYSROOT/lib/$DYNAMIC_LOADER" ]; then
  echo "  OK: $SYSROOT/lib/$DYNAMIC_LOADER"
else
  echo "  ERROR: $SYSROOT/lib/$DYNAMIC_LOADER is not reachable."
  echo
  echo "  Current top-level sysroot layout:"
  find "$SYSROOT" -maxdepth 1 -mindepth 1 -exec ls -ld {} \;
  exit 1
fi

echo
echo "Checking for absolute symlinks inside sysroot..."
ABS_LINK_COUNT="$(find "$SYSROOT" -type l -lname '/*' | wc -l)"
echo "  Absolute symlink count: $ABS_LINK_COUNT"

if [ "$ABS_LINK_COUNT" -gt 0 ]; then
  echo
  echo "First 25 absolute symlinks:"
  find "$SYSROOT" -type l -lname '/*' | head -25

  echo
  echo "NOTE:"
  echo "  Absolute symlinks may be OK, but if the linker later fails to find"
  echo "  a library that appears to exist, these may need to be rewritten."
fi

echo
echo "Sysroot summary:"
echo "------------------------------------------------------------"
ls -ld "$SYSROOT"
find "$SYSROOT" -maxdepth 1 -mindepth 1 -exec ls -ld {} \;
echo

echo "Key files:"
echo "------------------------------------------------------------"
ls -l "$SYSROOT/lib/$DYNAMIC_LOADER"
ls -ld "$SYSROOT/usr/include"
ls -ld "$SYSROOT/usr/lib/$ARCH_TRIPLET"
echo

echo "Done."
echo
echo "Suggested AqualinkD build command:"
echo "------------------------------------------------------------"
cat <<BUILD_EOF
cd ~/git/AqualinkD

make arm64 \\
  CC_ARM64="aarch64-linux-gnu-gcc --sysroot=$SYSROOT" \\
  LIBS="-L$SYSROOT/usr/lib/$ARCH_TRIPLET -Wl,-rpath-link,$SYSROOT/usr/lib/$ARCH_TRIPLET -lpthread -lm -lrt -lsystemd"
BUILD_EOF
