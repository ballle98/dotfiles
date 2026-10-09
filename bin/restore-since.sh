#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: restore-since.sh [OPTIONS] ARCHIVE DESTINATION

Extract ARCHIVE, preview an rsync restore into DESTINATION, and prompt before
performing the restore. By default, files newer at the destination are kept.

Options:
  -e, --extract-dir DIR  Use DIR for temporary extraction
  -f, --overwrite-older  Allow an older source file to replace a newer destination file
  -h, --help             Show this help

The default extraction directory is beside ARCHIVE and has the archive name
with its .tar.gz or .tgz suffix removed. The directory is removed on exit.
EOF
}

EXTRACT_ARG=""
OVERWRITE_OLDER=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    -e|--extract-dir)
      if [ "$#" -lt 2 ]; then
        printf 'Error: %s requires a directory\n' "$1" >&2
        usage >&2
        exit 2
      fi
      EXTRACT_ARG="$2"
      shift 2
      ;;
    --extract-dir=*)
      EXTRACT_ARG="${1#*=}"
      shift
      ;;
    -f|--overwrite-older)
      OVERWRITE_OLDER=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

if [ "$#" -ne 2 ]; then
  usage >&2
  exit 2
fi

ARCHIVE_ARG="$1"
DESTINATION_ARG="$2"

if [ ! -f "$ARCHIVE_ARG" ]; then
  printf 'Error: archive does not exist: %s\n' "$ARCHIVE_ARG" >&2
  exit 1
fi

if [ ! -d "$DESTINATION_ARG" ]; then
  printf 'Error: destination directory does not exist: %s\n' "$DESTINATION_ARG" >&2
  exit 1
fi

ARCHIVE_DIR="$(dirname "$ARCHIVE_ARG")"
ARCHIVE_DIR="$(cd "$ARCHIVE_DIR" && pwd -P)"
ARCHIVE="$ARCHIVE_DIR/$(basename "$ARCHIVE_ARG")"
DESTINATION="$(cd "$DESTINATION_ARG" && pwd -P)"

if [ -z "$EXTRACT_ARG" ]; then
  ARCHIVE_NAME="$(basename "$ARCHIVE")"
  case "$ARCHIVE_NAME" in
    *.tar.gz)
      EXTRACT_ARG="$ARCHIVE_DIR/${ARCHIVE_NAME%.tar.gz}"
      ;;
    *.tgz)
      EXTRACT_ARG="$ARCHIVE_DIR/${ARCHIVE_NAME%.tgz}"
      ;;
    *)
      printf 'Error: archive name must end in .tar.gz or .tgz\n' >&2
      exit 1
      ;;
  esac
fi

EXTRACT_NAME="$(basename "$EXTRACT_ARG")"
case "$EXTRACT_NAME" in
  ''|.|..|/)
    printf 'Error: unsafe extraction directory: %s\n' "$EXTRACT_ARG" >&2
    exit 1
    ;;
esac

EXTRACT_PARENT="$(dirname "$EXTRACT_ARG")"
mkdir -p "$EXTRACT_PARENT"
EXTRACT_PARENT="$(cd "$EXTRACT_PARENT" && pwd -P)"
EXTRACT_DIR="$EXTRACT_PARENT/$EXTRACT_NAME"

if [ -e "$EXTRACT_DIR" ]; then
  printf 'Error: extraction directory already exists: %s\n' "$EXTRACT_DIR" >&2
  printf 'Refusing to use it because the extraction directory is deleted on exit.\n' >&2
  exit 1
fi

EXTRACT_DIR_CREATED=false
cleanup() {
  if [ "$EXTRACT_DIR_CREATED" = true ] && [ -d "$EXTRACT_DIR" ]; then
    printf 'Removing temporary extraction directory: %s\n' "$EXTRACT_DIR"
    rm -rf -- "$EXTRACT_DIR"
  fi
}
trap cleanup EXIT

mkdir "$EXTRACT_DIR"
EXTRACT_DIR_CREATED=true

printf 'Archive:     %s\n' "$ARCHIVE"
printf 'Extracting:  %s\n' "$EXTRACT_DIR"
printf 'Destination: %s\n' "$DESTINATION"
if [ "$OVERWRITE_OLDER" = true ]; then
  printf '%s\n' 'Mode:        overwrite differing files even when the source is older'
else
  printf '%s\n' 'Mode:        keep destination files that are newer'
fi

tar --extract --gzip --file="$ARCHIVE" --directory="$EXTRACT_DIR"

RSYNC_OPTIONS=(
  --recursive
  --links
  --times
  --verbose
  --human-readable
  --no-perms
  --no-owner
  --no-group
  --modify-window=1
  --itemize-changes
)

if [ "$OVERWRITE_OLDER" = false ]; then
  RSYNC_OPTIONS+=(--update)
fi

printf '\n%s\n' 'Dry run:'
rsync "${RSYNC_OPTIONS[@]}" --dry-run "$EXTRACT_DIR/" "$DESTINATION/"

printf '\n%s' 'Continue with the restore? [y/N] '
if ! IFS= read -r REPLY; then
  printf '\n%s\n' 'Restore canceled.'
  exit 0
fi

case "$REPLY" in
  y|Y|yes|YES|Yes)
    ;;
  *)
    printf '%s\n' 'Restore canceled.'
    exit 0
    ;;
esac

printf '\n%s\n' 'Restoring:'
rsync "${RSYNC_OPTIONS[@]}" "$EXTRACT_DIR/" "$DESTINATION/"
printf '%s\n' 'Restore complete.'
