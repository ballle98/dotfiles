#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: archive-since.sh [-o OUTPUT_DIR] DIR SINCE

Create a gzip-compressed tar archive containing regular files in DIR that
were modified after SINCE. SINCE accepts any value understood by GNU date,
such as "3 months ago", "-3 months", or "2026-01-01".

Options:
  -o, --output-dir DIR  Write the archive to DIR instead of the current directory
  -h, --help            Show this help

The archive is named <directory>-recent-YYYY-MM-DD.tar.gz.
EOF
}

OUTPUT_DIR="$PWD"

while [ "$#" -gt 0 ]; do
  case "$1" in
    -o|--output-dir)
      if [ "$#" -lt 2 ]; then
        printf 'Error: %s requires a directory\n' "$1" >&2
        usage >&2
        exit 2
      fi
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --output-dir=*)
      OUTPUT_DIR="${1#*=}"
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

SOURCE_ARG="$1"
SINCE="$2"

if [ ! -d "$SOURCE_ARG" ]; then
  printf 'Error: directory does not exist: %s\n' "$SOURCE_ARG" >&2
  exit 1
fi

if ! CUTOFF="$(date -d "$SINCE" '+%Y-%m-%d %H:%M:%S')"; then
  printf 'Error: invalid since value: %s\n' "$SINCE" >&2
  exit 1
fi

SOURCE_DIR="$(cd "$SOURCE_ARG" && pwd -P)"
SOURCE_NAME="$(basename "$SOURCE_DIR")"
if [ "$SOURCE_NAME" = "/" ]; then
  SOURCE_NAME="root"
fi

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd -P)"
ARCHIVE="$OUTPUT_DIR/${SOURCE_NAME}-recent-$(date +%Y-%m-%d).tar.gz"

FILE_LIST="$(mktemp)"
trap 'rm -f "$FILE_LIST"' EXIT

printf 'Source:  %s\n' "$SOURCE_DIR"
printf 'Cutoff:  %s\n' "$CUTOFF"
printf 'Archive: %s\n' "$ARCHIVE"

cd "$SOURCE_DIR"
find . \
  -type f \
  -newermt "$CUTOFF" \
  ! -path "./${ARCHIVE#"$SOURCE_DIR"/}" \
  -print0 \
  > "$FILE_LIST"

tar \
  --create \
  --gzip \
  --file="$ARCHIVE" \
  --null \
  --files-from="$FILE_LIST"

printf 'Created: %s\n' "$ARCHIVE"
