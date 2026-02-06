#!/usr/bin/env bash
# List all Claude project directories related to current git repo (worktree-aware)
# Output: one directory path per line (only existing directories)

set -uo pipefail

# Get main repo path (works from any worktree)
MAIN_REPO=$(dirname "$(git rev-parse --git-common-dir)")

# Encode path for Claude's directory naming
# /Users/foo becomes -Users-foo (leading dash preserved)
encode_path() {
  echo "$1" | tr '/' '-'
}

# Collect all worktree paths
WORKTREES=()
while IFS= read -r line; do
  if [[ "$line" == worktree\ * ]]; then
    WORKTREES+=("${line#worktree }")
  fi
done < <(git worktree list --porcelain)

# Output directories that exist
for wt in "${WORKTREES[@]}"; do
  ENCODED=$(encode_path "$wt")
  DIR="$HOME/.claude/projects/$ENCODED"
  if [[ -d "$DIR" ]]; then
    echo "$DIR"
  fi
done
