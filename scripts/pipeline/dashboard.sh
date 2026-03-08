#!/opt/homebrew/bin/bash
# Pipeline Dashboard Generator
# Parses YAML frontmatter from active pipeline docs and computes state.
# Output: JSON summary suitable for orchestrator consumption + dashboard.md generation.
#
# Usage: ./scripts/pipeline/dashboard.sh [--json | --markdown]
#   --json      Output raw JSON (default)
#   --markdown  Output formatted markdown dashboard

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ACTIVE_DIR="$PROJECT_ROOT/docs/pipeline/active"
ARCHIVE_DIR="$PROJECT_ROOT/docs/pipeline/archive"
DASHBOARD_FILE="$PROJECT_ROOT/docs/pipeline/dashboard.md"

OUTPUT_FORMAT="${1:---json}"

# Build a map of branch -> worktree path from git worktree list
declare -A WORKTREE_MAP
build_worktree_map() {
    while IFS= read -r line; do
        local wt_path wt_branch
        wt_path=$(echo "$line" | awk '{print $1}')
        wt_branch=$(echo "$line" | sed -n 's/.*\[\(.*\)\].*/\1/p')
        if [ -n "$wt_branch" ]; then
            WORKTREE_MAP["$wt_branch"]="$wt_path"
        fi
    done < <(git -C "$PROJECT_ROOT" worktree list 2>/dev/null || true)
}
build_worktree_map

# Resolve the best file to read for a pipeline doc.
# If the pipeline has a worktree, prefer the worktree version.
# Usage: resolve_pipeline_file <main_file>
resolve_pipeline_file() {
    local main_file="$1"
    local rel_path="${main_file#$PROJECT_ROOT/}"

    # Quick check: read pipeline-branch from the main copy
    local branch
    branch=$(sed -n '/^---$/,/^---$/p' "$main_file" | grep "^pipeline-branch:" | head -1 | sed 's/^pipeline-branch: *//' | sed 's/^"\(.*\)"$/\1/')

    if [ -n "$branch" ] && [ "$branch" != "null" ]; then
        local wt_path="${WORKTREE_MAP[$branch]:-}"
        if [ -n "$wt_path" ] && [ -f "$wt_path/$rel_path" ]; then
            echo "$wt_path/$rel_path"
            return
        fi
    fi

    echo "$main_file"
}

# Extract YAML frontmatter value from a pipeline doc
# Usage: frontmatter_value <file> <key>
frontmatter_value() {
    local file="$1"
    local key="$2"
    sed -n '/^---$/,/^---$/p' "$file" | grep "^${key}:" | head -1 | sed "s/^${key}: *//" | sed 's/^"\(.*\)"$/\1/'
}

# Extract list field from YAML frontmatter (returns comma-separated)
# Usage: frontmatter_list <file> <key>
frontmatter_list() {
    local file="$1"
    local key="$2"
    sed -n '/^---$/,/^---$/p' "$file" | grep "^${key}:" | head -1 | sed "s/^${key}: *//" | sed 's/\[//;s/\]//' | sed 's/, */,/g'
}

# Build JSON array of active pipelines
build_active_json() {
    local first=true
    echo "["
    if [ -d "$ACTIVE_DIR" ]; then
        for main_file in "$ACTIVE_DIR"/p*.md; do
            [ -f "$main_file" ] || continue
            # Prefer worktree version if available
            local file
            file=$(resolve_pipeline_file "$main_file")
            if [ "$first" = true ]; then
                first=false
            else
                echo ","
            fi

            local id phase gate priority title slug source_bead blocked_by assigned_agent created updated pipeline_branch worktree_path
            id=$(frontmatter_value "$file" "id")
            phase=$(frontmatter_value "$file" "phase")
            gate=$(frontmatter_value "$file" "gate")
            priority=$(frontmatter_value "$file" "priority")
            title=$(frontmatter_value "$file" "title")
            slug=$(frontmatter_value "$file" "slug")
            source_bead=$(frontmatter_value "$file" "source-bead")
            blocked_by=$(frontmatter_list "$file" "blocked-by")
            assigned_agent=$(frontmatter_value "$file" "assigned-agent")
            created=$(frontmatter_value "$file" "created")
            updated=$(frontmatter_value "$file" "updated")
            pipeline_branch=$(frontmatter_value "$file" "pipeline-branch")
            worktree_path=$(frontmatter_value "$file" "worktree-path")

            # Convert blocked-by to JSON array
            local blocked_json="[]"
            if [ -n "$blocked_by" ] && [ "$blocked_by" != "[]" ]; then
                blocked_json=$(echo "$blocked_by" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | grep -v '^$' | jq -R . | jq -s .)
            fi

            # Calculate days in current phase
            local days_in_phase=0
            if [ -n "$updated" ] && [ "$updated" != "null" ]; then
                local updated_epoch current_epoch
                updated_epoch=$(date -j -f "%Y-%m-%d" "$updated" "+%s" 2>/dev/null || echo 0)
                current_epoch=$(date "+%s")
                if [ "$updated_epoch" -gt 0 ]; then
                    days_in_phase=$(( (current_epoch - updated_epoch) / 86400 ))
                fi
            fi

            cat <<ITEM
  {
    "id": $(echo "$id" | jq -R .),
    "slug": $(echo "$slug" | jq -R .),
    "title": $(echo "$title" | jq -R .),
    "phase": $(echo "$phase" | jq -R .),
    "gate": $(echo "$gate" | jq -R .),
    "priority": ${priority:-2},
    "source_bead": $(echo "${source_bead:-null}" | jq -R .),
    "blocked_by": $blocked_json,
    "assigned_agent": $(echo "${assigned_agent:-null}" | jq -R .),
    "created": $(echo "$created" | jq -R .),
    "updated": $(echo "$updated" | jq -R .),
    "pipeline_branch": $(echo "${pipeline_branch:-null}" | jq -R .),
    "worktree_path": $(echo "${worktree_path:-null}" | jq -R .),
    "from_worktree": $([ "$file" != "$main_file" ] && echo "true" || echo "false"),
    "days_in_phase": $days_in_phase,
    "file": $(echo "$file" | jq -R .)
  }
ITEM
        done
    fi
    echo "]"
}

# Count archived pipelines
count_archived() {
    if [ -d "$ARCHIVE_DIR" ]; then
        find "$ARCHIVE_DIR" -name "p*.md" -type f 2>/dev/null | wc -l | tr -d ' '
    else
        echo 0
    fi
}

# Main JSON output
build_json() {
    local active_json
    active_json=$(build_active_json)
    local archived_count
    archived_count=$(count_archived)
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Compute phase counts using jq
    local phase_counts
    phase_counts=$(echo "$active_json" | jq '{
        design: [.[] | select(.phase == "1-design")] | length,
        breakdown: [.[] | select(.phase == "2-breakdown")] | length,
        execution: [.[] | select(.phase == "3-execution")] | length,
        verification: [.[] | select(.phase == "4-verification")] | length
    }')

    local total_active
    total_active=$(echo "$active_json" | jq 'length')

    # Blocked pipelines
    local blocked
    blocked=$(echo "$active_json" | jq '[.[] | select(.blocked_by | length > 0)]')

    # Needs attention (pending gates, high priority)
    local needs_attention
    needs_attention=$(echo "$active_json" | jq '[.[] | select(.gate == "pending" or .gate == "blocked" or .gate == "waiting-for-human") | select(.blocked_by | length == 0)] | sort_by(.priority)')

    jq -n \
        --argjson pipelines "$active_json" \
        --argjson phase_counts "$phase_counts" \
        --arg timestamp "$timestamp" \
        --argjson archived "$archived_count" \
        --argjson total_active "$total_active" \
        --argjson needs_attention "$needs_attention" \
        --argjson blocked "$blocked" \
        '{
            timestamp: $timestamp,
            summary: {
                active: $total_active,
                archived: $archived,
                by_phase: $phase_counts
            },
            needs_attention: $needs_attention,
            blocked: $blocked,
            pipelines: $pipelines
        }'
}

# Markdown output
build_markdown() {
    local json
    json=$(build_json)
    local timestamp
    timestamp=$(echo "$json" | jq -r '.timestamp')

    cat <<HEADER
# Pipeline Dashboard
_Updated: ${timestamp}_

## Summary
| Phase | Count |
|-------|------:|
| Design | $(echo "$json" | jq '.summary.by_phase.design') |
| Breakdown | $(echo "$json" | jq '.summary.by_phase.breakdown') |
| Execution | $(echo "$json" | jq '.summary.by_phase.execution') |
| Verification | $(echo "$json" | jq '.summary.by_phase.verification') |
| **Active** | **$(echo "$json" | jq '.summary.active')** |
| Archived | $(echo "$json" | jq '.summary.archived') |

## Needs Your Attention
| Pipeline | Phase | Priority | What's Needed |
|----------|-------|:--------:|---------------|
HEADER

    echo "$json" | jq -r '.needs_attention[] | "| \(.id) \(.title) | \(.phase) | \(.priority) | \(if .gate == "waiting-for-human" then "Waiting for human input" else "Gate: \(.gate)" end) |"'

    cat <<RUNNING

## Running
| Pipeline | Phase | Priority | Agent | Days |
|----------|-------|:--------:|-------|-----:|
RUNNING

    echo "$json" | jq -r '.pipelines[] | select(.assigned_agent != "null" and .assigned_agent != null) | "| \(.id) \(.title) | \(.phase) | \(.priority) | \(.assigned_agent) | \(.days_in_phase) |"'

    cat <<BLOCKED

## Blocked
| Pipeline | Priority | Waiting On |
|----------|:--------:|------------|
BLOCKED

    echo "$json" | jq -r '.blocked[] | "| \(.id) \(.title) | \(.priority) | \(.blocked_by | join(", ")) |"'

    echo ""
}

case "$OUTPUT_FORMAT" in
    --json)
        build_json
        ;;
    --markdown)
        build_markdown | tee "$DASHBOARD_FILE"
        echo "" >&2
        echo "Dashboard written to $DASHBOARD_FILE" >&2
        ;;
    *)
        echo "Usage: $0 [--json | --markdown]" >&2
        exit 1
        ;;
esac
