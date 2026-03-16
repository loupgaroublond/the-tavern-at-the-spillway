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

    # Strategy 1: read pipeline-branch from the main copy
    local branch
    branch=$(sed -n '/^---$/,/^---$/p' "$main_file" | grep "^pipeline-branch:" | head -1 | sed 's/^pipeline-branch: *//' | sed 's/^"\(.*\)"$/\1/')

    if [ -n "$branch" ] && [ "$branch" != "null" ]; then
        local wt_path="${WORKTREE_MAP[$branch]:-}"
        if [ -n "$wt_path" ] && [ -f "$wt_path/$rel_path" ]; then
            echo "$wt_path/$rel_path"
            return
        fi
    fi

    # Fallback: match by pipeline ID from filename against worktree branches
    local pipeline_id
    pipeline_id=$(basename "$main_file" | grep -o '^p[0-9]*')
    if [ -n "$pipeline_id" ]; then
        for wt_branch in "${!WORKTREE_MAP[@]}"; do
            if [[ "$wt_branch" == pipeline/${pipeline_id}-* ]]; then
                local wt_path="${WORKTREE_MAP[$wt_branch]}"
                if [ -f "$wt_path/$rel_path" ]; then
                    echo "$wt_path/$rel_path"
                    return
                fi
            fi
        done
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

    local total_active
    total_active=$(echo "$active_json" | jq 'length')

    # Gate-based categorization:
    # - gate1: phase 1-design (or "design"), gate ready-for-review — awaiting human G1 approval
    # - gate2: phase 2-breakdown, gate ready-for-review — awaiting human G2 approval
    # - gate3: phase 3-execution, gate ready-for-review — awaiting self-review + scope check
    # - gate4: phase 4-verification — in verification
    # - blocked: has blocked-by entries (regardless of phase)
    # - inactive: no assigned agent, not blocked — backlog stubs

    local gate1 gate2 gate3 gate4 in_progress completed blocked inactive

    blocked=$(echo "$active_json" | jq '[.[] | select(.blocked_by | length > 0)] | sort_by(.priority)')

    # Exclude blocked pipelines from gate buckets
    gate1=$(echo "$active_json" | jq '[.[] | select(.blocked_by | length == 0) | select(.phase == "1-design" or .phase == "design") | select(.gate == "ready-for-review")] | sort_by(.priority)')

    gate2=$(echo "$active_json" | jq '[.[] | select(.blocked_by | length == 0) | select(.phase == "2-breakdown") | select(.gate == "ready-for-review")] | sort_by(.priority)')

    gate3=$(echo "$active_json" | jq '[.[] | select(.blocked_by | length == 0) | select(.phase == "3-execution") | select(.gate == "ready-for-review")] | sort_by(.priority)')

    gate4=$(echo "$active_json" | jq '[.[] | select(.blocked_by | length == 0) | select(.phase == "4-verification")] | sort_by(.priority)')

    # In progress: has assigned agent, not at a gate review, not blocked, not completed
    in_progress=$(echo "$active_json" | jq '[.[] | select(.blocked_by | length == 0) | select(.gate != "ready-for-review") | select(.phase != "4-verification") | select(.phase != "completed" and .phase != "archived" and .phase != "merged") | select(.assigned_agent != null and .assigned_agent != "null" and .assigned_agent != "")] | sort_by(.priority)')

    # Completed: phase is completed, archived, or merged
    completed=$(echo "$active_json" | jq '[.[] | select(.phase == "completed" or .phase == "archived" or .phase == "merged" or .gate == "completed")] | sort_by(.priority)')

    # Inactive: no assigned agent, not blocked, not at a gate, not completed
    inactive=$(echo "$active_json" | jq '[.[] | select(.blocked_by | length == 0) | select(.gate != "ready-for-review") | select(.phase != "4-verification") | select(.phase != "completed" and .phase != "archived" and .phase != "merged") | select(.gate != "completed") | select(.assigned_agent == null or .assigned_agent == "null" or .assigned_agent == "")] | sort_by(.priority)')

    jq -n \
        --argjson pipelines "$active_json" \
        --arg timestamp "$timestamp" \
        --argjson archived "$archived_count" \
        --argjson total_active "$total_active" \
        --argjson gate1 "$gate1" \
        --argjson gate2 "$gate2" \
        --argjson gate3 "$gate3" \
        --argjson gate4 "$gate4" \
        --argjson in_progress "$in_progress" \
        --argjson completed "$completed" \
        --argjson blocked "$blocked" \
        --argjson inactive "$inactive" \
        '{
            timestamp: $timestamp,
            summary: {
                active: $total_active,
                archived: $archived,
                gate1: ($gate1 | length),
                gate2: ($gate2 | length),
                gate3: ($gate3 | length),
                gate4: ($gate4 | length),
                in_progress: ($in_progress | length),
                completed: ($completed | length),
                blocked: ($blocked | length),
                inactive: ($inactive | length)
            },
            gate1: $gate1,
            gate2: $gate2,
            gate3: $gate3,
            gate4: $gate4,
            in_progress: $in_progress,
            completed: $completed,
            blocked: $blocked,
            inactive: $inactive,
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
| Section | Count |
|---------|------:|
| Gate 1 (Design Review) | $(echo "$json" | jq '.summary.gate1') |
| Gate 2 (Breakdown Review) | $(echo "$json" | jq '.summary.gate2') |
| Gate 3 (Self-Review) | $(echo "$json" | jq '.summary.gate3') |
| Gate 4 (Verification) | $(echo "$json" | jq '.summary.gate4') |
| In Progress | $(echo "$json" | jq '.summary.in_progress') |
| Completed | $(echo "$json" | jq '.summary.completed') |
| Blocked | $(echo "$json" | jq '.summary.blocked') |
| Inactive | $(echo "$json" | jq '.summary.inactive') |
| **Total** | **$(echo "$json" | jq '.summary.active')** |
| Archived | $(echo "$json" | jq '.summary.archived') |

## Gate 1 — Design Review
| Pipeline | Priority | Agent |
|----------|:--------:|-------|
HEADER

    echo "$json" | jq -r '.gate1[] | "| \(.id) \(.title) | \(.priority) | \(if .assigned_agent != "null" and .assigned_agent != null and .assigned_agent != "" then .assigned_agent else "—" end) |"'

    cat <<GATE2

## Gate 2 — Breakdown Review
| Pipeline | Priority | Agent |
|----------|:--------:|-------|
GATE2

    echo "$json" | jq -r '.gate2[] | "| \(.id) \(.title) | \(.priority) | \(if .assigned_agent != "null" and .assigned_agent != null and .assigned_agent != "" then .assigned_agent else "—" end) |"'

    cat <<GATE3

## Gate 3 — Self-Review + Scope Check
| Pipeline | Priority | Agent |
|----------|:--------:|-------|
GATE3

    echo "$json" | jq -r '.gate3[] | "| \(.id) \(.title) | \(.priority) | \(if .assigned_agent != "null" and .assigned_agent != null and .assigned_agent != "" then .assigned_agent else "—" end) |"'

    cat <<GATE4

## Gate 4 — Verification
| Pipeline | Priority | Agent |
|----------|:--------:|-------|
GATE4

    echo "$json" | jq -r '.gate4[] | "| \(.id) \(.title) | \(.priority) | \(if .assigned_agent != "null" and .assigned_agent != null and .assigned_agent != "" then .assigned_agent else "—" end) |"'

    cat <<INPROGRESS

## In Progress
| Pipeline | Priority | Agent | Phase |
|----------|:--------:|-------|-------|
INPROGRESS

    echo "$json" | jq -r '.in_progress[] | "| \(.id) \(.title) | \(.priority) | \(if .assigned_agent != "null" and .assigned_agent != null and .assigned_agent != "" then .assigned_agent else "—" end) | \(.phase) |"'

    cat <<COMPLETED

## Completed
| Pipeline | Priority |
|----------|:--------:|
COMPLETED

    echo "$json" | jq -r '.completed[] | "| \(.id) \(.title) | \(.priority) |"'

    cat <<BLOCKED

## Blocked
| Pipeline | Priority | Waiting On |
|----------|:--------:|------------|
BLOCKED

    echo "$json" | jq -r '.blocked[] | "| \(.id) \(.title) | \(.priority) | \(.blocked_by | join(", ")) |"'

    cat <<INACTIVE

## Inactive
| Pipeline | Priority | Phase |
|----------|:--------:|-------|
INACTIVE

    echo "$json" | jq -r '.inactive[] | "| \(.id) \(.title) | \(.priority) | \(.phase) |"'

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
