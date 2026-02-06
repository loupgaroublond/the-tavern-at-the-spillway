#!/usr/bin/env bash
# List deduplicated sessions across all related project directories
# Uses list-project-dirs.sh to find directories, deduplicates by session ID
#
# Options:
#   --min-size BYTES  Only show sessions larger than BYTES (default: 0)
#   --json            Output as JSON array
#   --paths-only      Output only file paths (for piping)
#   --quick           Skip timestamp parsing (faster, uses mtime instead)
#
# Output (default): timestamp | size | session_id | path

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIN_SIZE=0
JSON_OUTPUT=false
PATHS_ONLY=false
QUICK_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --min-size) MIN_SIZE="$2"; shift 2 ;;
    --json) JSON_OUTPUT=true; shift ;;
    --paths-only) PATHS_ONLY=true; shift ;;
    --quick) QUICK_MODE=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Collect sessions, preferring newest copy by modification time
declare -A SESSION_FILES
declare -A SESSION_MTIMES

while IFS= read -r dir; do
  for f in "$dir"/*.jsonl; do
    [[ -f "$f" ]] || continue
    id=$(basename "$f" .jsonl)
    mtime=$(stat -f%m "$f" 2>/dev/null || stat -c%Y "$f" 2>/dev/null)

    # Use newest file if duplicate ID exists
    if [[ -z "${SESSION_FILES[$id]:-}" ]] || [[ "$mtime" -gt "${SESSION_MTIMES[$id]:-0}" ]]; then
      SESSION_FILES[$id]="$f"
      SESSION_MTIMES[$id]="$mtime"
    fi
  done
done < <("$SCRIPT_DIR/list-project-dirs.sh")

# Output sessions
if $JSON_OUTPUT; then
  echo "["
  first=true
  for id in "${!SESSION_FILES[@]}"; do
    f="${SESSION_FILES[$id]}"
    size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null)
    [[ $size -lt $MIN_SIZE ]] && continue

    # Get timestamp from first few lines (efficient - don't read whole file)
    ts=$(head -5 "$f" | jq -r 'select(.timestamp) | .timestamp' 2>/dev/null | head -1)

    $first || echo ","
    first=false
    printf '  {"id": "%s", "path": "%s", "size": %d, "timestamp": "%s"}' "$id" "$f" "$size" "$ts"
  done
  echo ""
  echo "]"
elif $PATHS_ONLY; then
  for id in "${!SESSION_FILES[@]}"; do
    f="${SESSION_FILES[$id]}"
    size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null)
    [[ $size -lt $MIN_SIZE ]] && continue
    echo "$f"
  done
else
  # Default: human-readable sorted by timestamp
  for id in "${!SESSION_FILES[@]}"; do
    f="${SESSION_FILES[$id]}"
    size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null)
    [[ $size -lt $MIN_SIZE ]] && continue

    if $QUICK_MODE; then
      # Use file mtime instead of parsing (much faster)
      mtime="${SESSION_MTIMES[$id]}"
      ts=$(date -r "$mtime" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date -d "@$mtime" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || echo "unknown")
    else
      # Get timestamp from first few lines (efficient - don't read whole file)
      ts=$(head -5 "$f" | jq -r 'select(.timestamp) | .timestamp' 2>/dev/null | head -1)
      [[ -z "$ts" ]] && ts="unknown"
    fi

    # Human-readable size (macOS compatible, bash arithmetic)
    if [[ $size -ge 1073741824 ]]; then
      size_h="$((size / 1073741824)).$((size % 1073741824 * 10 / 1073741824))G"
    elif [[ $size -ge 1048576 ]]; then
      size_h="$((size / 1048576)).$((size % 1048576 * 10 / 1048576))M"
    elif [[ $size -ge 1024 ]]; then
      size_h="$((size / 1024)).$((size % 1024 * 10 / 1024))K"
    else
      size_h="${size}B"
    fi
    echo "$ts | $size_h | $id | $f"
  done | sort
fi
