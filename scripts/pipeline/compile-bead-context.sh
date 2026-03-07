#!/bin/bash
# Compile Bead Context Bundle
# Reads a context-source specification and produces a single compiled document
# for an execution agent to consume.
#
# Usage: ./scripts/pipeline/compile-bead-context.sh <pipeline-doc> <work-item-id>
#   or:  ./scripts/pipeline/compile-bead-context.sh --spec <spec-file>
#
# Context-source spec format (YAML):
#   context-sources:
#     instructions: [core, agent-core]
#     specs: [REQ-AGT-004, REQ-LCM-001]
#     adrs: [ADR-001 section-3.2, ADR-003 section-2]
#     code: [Jake.swift:1-50, MortalSpawner.swift:init]
#     design-statements: [items 2-3]
#
# Output: Compiled markdown to stdout

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INSTRUCTIONS_DIR="$PROJECT_ROOT/docs/pipeline/instructions"
SPEC_DIR="$PROJECT_ROOT/docs/2-spec"
ADR_DIR="$PROJECT_ROOT/docs/3-adr"
SOURCES_DIR="$PROJECT_ROOT/Tavern/Sources"

# ── Helpers ──────────────────────────────────────────────────────────

# Find a source file by name (searches Sources/ recursively)
find_source_file() {
    local filename="$1"
    find "$SOURCES_DIR" -name "$filename" -type f 2>/dev/null | head -1
}

# Find a spec module containing a requirement ID
find_spec_for_req() {
    local req_id="$1"
    grep -rl "$req_id" "$SPEC_DIR"/*.md 2>/dev/null | head -1
}

# Extract lines from a file
# Usage: extract_lines <file> <start> <end>
extract_lines() {
    local file="$1"
    local start="$2"
    local end="$3"
    sed -n "${start},${end}p" "$file"
}

# Extract a requirement block from a spec file
# Finds the REQ-* heading and extracts until the next heading of same or higher level
extract_requirement() {
    local req_id="$1"
    local spec_file
    spec_file=$(find_spec_for_req "$req_id")
    if [ -z "$spec_file" ]; then
        echo "<!-- Requirement $req_id not found -->"
        return
    fi

    # Find the line with the requirement, extract the section
    local start_line
    start_line=$(grep -n "$req_id" "$spec_file" | head -1 | cut -d: -f1)
    if [ -z "$start_line" ]; then
        echo "<!-- Requirement $req_id not found in $spec_file -->"
        return
    fi

    # Extract from the heading containing req_id to the next heading of same/higher level
    local total_lines
    total_lines=$(wc -l < "$spec_file" | tr -d ' ')

    # Find the heading level
    local heading_line
    heading_line=$(sed -n "${start_line}p" "$spec_file")
    local heading_level
    heading_level=$(echo "$heading_line" | grep -o '^#*' | wc -c | tr -d ' ')

    # Find the next heading of same or higher level
    local end_line=$total_lines
    local search_start=$((start_line + 1))
    if [ "$search_start" -le "$total_lines" ]; then
        local next_heading
        next_heading=$(tail -n +"$search_start" "$spec_file" | grep -n "^#\{1,${heading_level}\} " | head -1 | cut -d: -f1)
        if [ -n "$next_heading" ]; then
            end_line=$((search_start + next_heading - 2))
        fi
    fi

    extract_lines "$spec_file" "$start_line" "$end_line"
}

# Extract an ADR section
# Usage: extract_adr_section "ADR-001" "section-3.2" or "ADR-001" (full doc)
extract_adr_section() {
    local adr_ref="$1"
    local adr_num
    adr_num=$(echo "$adr_ref" | grep -o 'ADR-[0-9]*')
    local section
    section=$(echo "$adr_ref" | sed "s/$adr_num//" | sed 's/^ *//')

    # Find the ADR file
    local adr_file
    adr_file=$(find "$ADR_DIR" -name "${adr_num}*" -type f 2>/dev/null | head -1)
    if [ -z "$adr_file" ]; then
        echo "<!-- $adr_num not found -->"
        return
    fi

    if [ -z "$section" ]; then
        # Return full ADR
        cat "$adr_file"
    else
        # Extract specific section (e.g., "section-3.2" -> heading "3.2" or "## 3.2")
        local section_num
        section_num=$(echo "$section" | sed 's/section-//')
        local start_line
        start_line=$(grep -n "^#.*${section_num}" "$adr_file" | head -1 | cut -d: -f1)
        if [ -z "$start_line" ]; then
            echo "<!-- Section $section_num not found in $adr_file -->"
            return
        fi
        local total_lines
        total_lines=$(wc -l < "$adr_file" | tr -d ' ')
        local heading_line
        heading_line=$(sed -n "${start_line}p" "$adr_file")
        local heading_level
        heading_level=$(echo "$heading_line" | grep -o '^#*' | wc -c | tr -d ' ')

        local end_line=$total_lines
        local search_start=$((start_line + 1))
        if [ "$search_start" -le "$total_lines" ]; then
            local next_heading
            next_heading=$(tail -n +"$search_start" "$adr_file" | grep -n "^#\{1,${heading_level}\} " | head -1 | cut -d: -f1)
            if [ -n "$next_heading" ]; then
                end_line=$((search_start + next_heading - 2))
            fi
        fi
        extract_lines "$adr_file" "$start_line" "$end_line"
    fi
}

# Extract code excerpt
# Usage: extract_code "Jake.swift:1-50" or "MortalSpawner.swift:init"
extract_code() {
    local ref="$1"
    local filename
    filename=$(echo "$ref" | cut -d: -f1)
    local range
    range=$(echo "$ref" | cut -d: -f2)

    local filepath
    filepath=$(find_source_file "$filename")
    if [ -z "$filepath" ]; then
        echo "<!-- File $filename not found -->"
        return
    fi

    echo "\`\`\`swift"
    echo "// $filepath"
    if echo "$range" | grep -q '^[0-9]*-[0-9]*$'; then
        # Line range: 1-50
        local start end
        start=$(echo "$range" | cut -d- -f1)
        end=$(echo "$range" | cut -d- -f2)
        extract_lines "$filepath" "$start" "$end"
    elif echo "$range" | grep -q '^[0-9]*$'; then
        # Single line
        sed -n "${range}p" "$filepath"
    else
        # Symbol name: search for it and extract context
        local symbol_line
        symbol_line=$(grep -n "$range" "$filepath" | head -1 | cut -d: -f1)
        if [ -n "$symbol_line" ]; then
            local ctx_start=$((symbol_line > 5 ? symbol_line - 5 : 1))
            local ctx_end=$((symbol_line + 50))
            extract_lines "$filepath" "$ctx_start" "$ctx_end"
        else
            echo "// Symbol '$range' not found in $filename"
        fi
    fi
    echo "\`\`\`"
}

# ── Spec File Mode ───────────────────────────────────────────────────

compile_from_spec() {
    local spec_file="$1"
    if [ ! -f "$spec_file" ]; then
        echo "Error: Spec file not found: $spec_file" >&2
        exit 1
    fi

    echo "# Compiled Bead Context"
    echo ""
    echo "_Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")_"
    echo "_Source: $spec_file_"
    echo ""

    # Parse the YAML-like spec file
    # Expected format:
    # instructions: [core, agent-core]
    # specs: [REQ-AGT-004, REQ-LCM-001]
    # adrs: [ADR-001 section-3.2]
    # code: [Jake.swift:1-50]
    # design-statements-file: <path>
    # design-statements-items: [2, 3]

    # Instructions
    local instructions
    instructions=$(grep '^instructions:' "$spec_file" 2>/dev/null | sed 's/^instructions: *//' | sed 's/\[//;s/\]//' | tr ',' '\n' | sed 's/^ *//;s/ *$//')
    if [ -n "$instructions" ]; then
        echo "---"
        echo ""
        echo "## Distilled Instructions"
        echo ""
        while IFS= read -r inst; do
            [ -z "$inst" ] && continue
            local inst_file="$INSTRUCTIONS_DIR/${inst}.md"
            if [ -f "$inst_file" ]; then
                cat "$inst_file"
                echo ""
            else
                echo "<!-- Instruction set '$inst' not found at $inst_file -->"
            fi
        done <<< "$instructions"
    fi

    # Specs
    local specs
    specs=$(grep '^specs:' "$spec_file" 2>/dev/null | sed 's/^specs: *//' | sed 's/\[//;s/\]//' | tr ',' '\n' | sed 's/^ *//;s/ *$//')
    if [ -n "$specs" ]; then
        echo "---"
        echo ""
        echo "## Relevant Specifications"
        echo ""
        while IFS= read -r req; do
            [ -z "$req" ] && continue
            echo "### $req"
            echo ""
            extract_requirement "$req"
            echo ""
        done <<< "$specs"
    fi

    # ADRs
    local adrs
    adrs=$(grep '^adrs:' "$spec_file" 2>/dev/null | sed 's/^adrs: *//' | sed 's/\[//;s/\]//' | tr ',' '\n' | sed 's/^ *//;s/ *$//')
    if [ -n "$adrs" ]; then
        echo "---"
        echo ""
        echo "## Architecture Decisions"
        echo ""
        while IFS= read -r adr; do
            [ -z "$adr" ] && continue
            extract_adr_section "$adr"
            echo ""
        done <<< "$adrs"
    fi

    # Code
    local code_refs
    code_refs=$(grep '^code:' "$spec_file" 2>/dev/null | sed 's/^code: *//' | sed 's/\[//;s/\]//' | tr ',' '\n' | sed 's/^ *//;s/ *$//')
    if [ -n "$code_refs" ]; then
        echo "---"
        echo ""
        echo "## Code Context"
        echo ""
        while IFS= read -r cref; do
            [ -z "$cref" ] && continue
            extract_code "$cref"
            echo ""
        done <<< "$code_refs"
    fi

    # Design statements
    local ds_file
    ds_file=$(grep '^design-statements-file:' "$spec_file" 2>/dev/null | sed 's/^design-statements-file: *//')
    if [ -n "$ds_file" ] && [ -f "$ds_file" ]; then
        echo "---"
        echo ""
        echo "## Design Statements"
        echo ""
        # Extract Design Statements section from the pipeline doc
        local ds_start
        ds_start=$(grep -n "^## Design Statements" "$ds_file" | head -1 | cut -d: -f1)
        if [ -n "$ds_start" ]; then
            local ds_end
            ds_end=$(tail -n +"$((ds_start + 1))" "$ds_file" | grep -n "^## " | head -1 | cut -d: -f1)
            if [ -n "$ds_end" ]; then
                ds_end=$((ds_start + ds_end - 1))
            else
                ds_end=$(wc -l < "$ds_file" | tr -d ' ')
            fi
            extract_lines "$ds_file" "$ds_start" "$ds_end"
        fi
    fi
}

# ── Main ─────────────────────────────────────────────────────────────

if [ "${1:-}" = "--spec" ]; then
    if [ -z "${2:-}" ]; then
        echo "Usage: $0 --spec <spec-file>" >&2
        exit 1
    fi
    compile_from_spec "$2"
elif [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    cat <<'HELP'
Compile Bead Context Bundle

Usage:
  compile-bead-context.sh --spec <spec-file>    Compile from a context-source spec file
  compile-bead-context.sh --help                Show this help

Spec file format (plain text, one key per line):
  instructions: [core, agent-core]
  specs: [REQ-AGT-004, REQ-LCM-001]
  adrs: [ADR-001 section-3.2, ADR-003]
  code: [Jake.swift:1-50, MortalSpawner.swift:init]
  design-statements-file: docs/pipeline/active/p0000-jukebox.md

Output: Compiled markdown to stdout containing all referenced material.
HELP
else
    echo "Usage: $0 --spec <spec-file>" >&2
    echo "       $0 --help" >&2
    exit 1
fi
