#!/bin/bash
# Line of Code Counter for Tavern project
# Separates project code from dependencies, docs, and transcripts

set -e
cd "$(dirname "$0")/.."

echo "═══════════════════════════════════════════════════════════════"
echo "  Line Count Report: The Tavern at the Spillway"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Helper function to count lines
count_lines() {
    local pattern="$1"
    local exclude="$2"
    if [ -n "$exclude" ]; then
        find . -type f -name "$pattern" ! -path "./.build/*" ! -path "./.git/*" ! -path "$exclude" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}'
    else
        find . -type f -name "$pattern" ! -path "./.build/*" ! -path "./.git/*" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}'
    fi
}

# Helper to count files
count_files() {
    local pattern="$1"
    find . -type f -name "$pattern" ! -path "./.build/*" ! -path "./.git/*" 2>/dev/null | wc -l | tr -d ' '
}

echo "┌─────────────────────────────────────────────────────────────┐"
echo "│  PROJECT CODE (Tavern/Sources, Tavern/Tests)                │"
echo "└─────────────────────────────────────────────────────────────┘"

swift_src_lines=$(find Tavern/Sources -name "*.swift" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
swift_src_files=$(find Tavern/Sources -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')

swift_test_lines=$(find Tavern/Tests -name "*.swift" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
swift_test_files=$(find Tavern/Tests -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')

echo ""
printf "  %-40s %8s lines  (%s files)\n" "Swift Source (Tavern/Sources)" "${swift_src_lines:-0}" "${swift_src_files:-0}"
printf "  %-40s %8s lines  (%s files)\n" "Swift Tests (Tavern/Tests)" "${swift_test_lines:-0}" "${swift_test_files:-0}"
echo "  ─────────────────────────────────────────────────────────────"
total_tavern=$((${swift_src_lines:-0} + ${swift_test_lines:-0}))
total_tavern_files=$((${swift_src_files:-0} + ${swift_test_files:-0}))
printf "  %-40s %8s lines  (%s files)\n" "SUBTOTAL (Tavern)" "$total_tavern" "$total_tavern_files"

echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│  LOCAL SDK (Tavern/LocalPackages/ClaudeCodeSDK)             │"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""

sdk_src_lines=$(find Tavern/LocalPackages/ClaudeCodeSDK/Sources -name "*.swift" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
sdk_src_files=$(find Tavern/LocalPackages/ClaudeCodeSDK/Sources -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')

sdk_test_lines=$(find Tavern/LocalPackages/ClaudeCodeSDK/Tests -name "*.swift" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
sdk_test_files=$(find Tavern/LocalPackages/ClaudeCodeSDK/Tests -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')

printf "  %-40s %8s lines  (%s files)\n" "SDK Source" "${sdk_src_lines:-0}" "${sdk_src_files:-0}"
printf "  %-40s %8s lines  (%s files)\n" "SDK Tests" "${sdk_test_lines:-0}" "${sdk_test_files:-0}"
echo "  ─────────────────────────────────────────────────────────────"
total_sdk=$((${sdk_src_lines:-0} + ${sdk_test_lines:-0}))
total_sdk_files=$((${sdk_src_files:-0} + ${sdk_test_files:-0}))
printf "  %-40s %8s lines  (%s files)\n" "SUBTOTAL (SDK)" "$total_sdk" "$total_sdk_files"

echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│  SCRIPTS & SANDBOX (scripts/, sandbox/)                     │"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""

scripts_swift_lines=$(find scripts -name "*.swift" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
scripts_swift_files=$(find scripts -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')

sandbox_swift_lines=$(find sandbox -name "*.swift" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
sandbox_swift_files=$(find sandbox -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')

printf "  %-40s %8s lines  (%s files)\n" "scripts/*.swift" "${scripts_swift_lines:-0}" "${scripts_swift_files:-0}"
printf "  %-40s %8s lines  (%s files)\n" "sandbox/*.swift" "${sandbox_swift_lines:-0}" "${sandbox_swift_files:-0}"
echo "  ─────────────────────────────────────────────────────────────"
total_scripts=$((${scripts_swift_lines:-0} + ${sandbox_swift_lines:-0}))
total_scripts_files=$((${scripts_swift_files:-0} + ${sandbox_swift_files:-0}))
printf "  %-40s %8s lines  (%s files)\n" "SUBTOTAL (Scripts/Sandbox)" "$total_scripts" "$total_scripts_files"

echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│  CONFIGURATION & BUILD                                      │"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""

package_lines=$(wc -l < Tavern/Package.swift 2>/dev/null || echo 0)
project_yml_lines=$(wc -l < Tavern/project.yml 2>/dev/null || echo 0)
gitignore_lines=$(wc -l < Tavern/.gitignore 2>/dev/null || echo 0)

printf "  %-40s %8s lines\n" "Package.swift" "$package_lines"
printf "  %-40s %8s lines\n" "project.yml (XcodeGen)" "$project_yml_lines"
printf "  %-40s %8s lines\n" ".gitignore" "$gitignore_lines"

echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│  DOCUMENTATION (docs/)                                      │"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""

# Top-level docs (docs/*.md, excluding subdirectories)
docs_top_lines=$(find docs -maxdepth 1 -name "*.md" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
docs_top_files=$(find docs -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

# Architecture proposals
arch_proposals_lines=$(find docs/architecture-proposals -name "*.md" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
arch_proposals_files=$(find docs/architecture-proposals -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

printf "  %-40s %8s lines  (%s files)\n" "Top-level docs (docs/*.md)" "${docs_top_lines:-0}" "${docs_top_files:-0}"
printf "  %-40s %8s lines  (%s files)\n" "Architecture Proposals" "${arch_proposals_lines:-0}" "${arch_proposals_files:-0}"
echo "  ─────────────────────────────────────────────────────────────"
total_docs_dir=$((${docs_top_lines:-0} + ${arch_proposals_lines:-0}))
total_docs_dir_files=$((${docs_top_files:-0} + ${arch_proposals_files:-0}))
printf "  %-40s %8s lines  (%s files)\n" "SUBTOTAL (docs/)" "$total_docs_dir" "$total_docs_dir_files"

echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│  ROOT-LEVEL DOCS                                            │"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""

claude_md_lines=$(wc -l < CLAUDE.md 2>/dev/null || echo 0)
readme_lines=$(wc -l < README.md 2>/dev/null || echo 0)

printf "  %-40s %8s lines\n" "CLAUDE.md" "$claude_md_lines"
printf "  %-40s %8s lines\n" "README.md" "$readme_lines"

echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│  SEED DESIGN DOCUMENTS (docs/seed-design/)                  │"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""

# Transcripts
transcript_lines=$(find docs/seed-design -name "transcript_*.md" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
transcript_files=$(find docs/seed-design -name "transcript_*.md" 2>/dev/null | wc -l | tr -d ' ')

# PRD and planning docs
prd_lines=$(wc -l < docs/seed-design/prd_2026-01-19.md 2>/dev/null || echo 0)
impl_plan_lines=$(wc -l < docs/seed-design/v1-implementation-plan.md 2>/dev/null || echo 0)

# Process/reader docs
process_lines=$(find docs/seed-design -name "process_*.md" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
reader_lines=$(find docs/seed-design -name "reader_*.md" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')

# Vocab docs
vocab_lines=$(find docs/seed-design -name "vocab_*.md" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
vocab_files=$(find docs/seed-design -name "vocab_*.md" 2>/dev/null | wc -l | tr -d ' ')

# Notes
notes_lines=$(find docs/seed-design -name "notes_*.md" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')

printf "  %-40s %8s lines  (%s files)\n" "Transcripts" "${transcript_lines:-0}" "${transcript_files:-0}"
printf "  %-40s %8s lines\n" "PRD" "${prd_lines:-0}"
printf "  %-40s %8s lines\n" "Implementation Plan" "${impl_plan_lines:-0}"
printf "  %-40s %8s lines\n" "Process docs" "${process_lines:-0}"
printf "  %-40s %8s lines\n" "Reader analysis" "${reader_lines:-0}"
printf "  %-40s %8s lines  (%s files)\n" "Vocabulary docs" "${vocab_lines:-0}" "${vocab_files:-0}"
printf "  %-40s %8s lines\n" "Notes" "${notes_lines:-0}"
echo "  ─────────────────────────────────────────────────────────────"
total_seed=$((${transcript_lines:-0} + ${prd_lines:-0} + ${impl_plan_lines:-0} + ${process_lines:-0} + ${reader_lines:-0} + ${vocab_lines:-0} + ${notes_lines:-0}))
printf "  %-40s %8s lines\n" "SUBTOTAL (seed-design)" "$total_seed"

echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│  ARCHIVE                                                    │"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""

archive_lines=$(find archive -type f -name "*.md" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
archive_files=$(find archive -type f 2>/dev/null | wc -l | tr -d ' ')

printf "  %-40s %8s lines  (%s files)\n" "Archive" "${archive_lines:-0}" "${archive_files:-0}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  SUMMARY"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Swift totals
total_swift=$((${total_tavern:-0} + ${total_sdk:-0} + ${total_scripts:-0}))
total_swift_files=$((${total_tavern_files:-0} + ${total_sdk_files:-0} + ${total_scripts_files:-0}))

# Documentation totals
total_docs=$((${claude_md_lines:-0} + ${readme_lines:-0} + ${total_docs_dir:-0} + ${total_seed:-0} + ${archive_lines:-0}))

# Grand total
total_all=$((${total_swift:-0} + ${total_docs:-0}))

printf "  %-40s %8s lines  (%s files)\n" "Swift Code (all)" "$total_swift" "$total_swift_files"
printf "  %-9s%-31s %8s lines\n" "" "├─ Tavern (Sources/Tests)" "$total_tavern"
printf "  %-9s%-31s %8s lines\n" "" "├─ SDK (LocalPackages)" "$total_sdk"
printf "  %-9s%-31s %8s lines\n" "" "└─ Scripts/Sandbox" "$total_scripts"
echo ""
printf "  %-40s %8s lines\n" "Documentation & Design (all)" "$total_docs"
printf "  %-9s%-31s %8s lines\n" "" "├─ docs/ directory" "$total_docs_dir"
printf "  %-9s%-31s %8s lines\n" "" "├─ seed-design/" "$total_seed"
printf "  %-9s%-31s %8s lines\n" "" "├─ Root docs (CLAUDE.md, etc)" "$((${claude_md_lines:-0} + ${readme_lines:-0}))"
printf "  %-9s%-31s %8s lines\n" "" "└─ Archive" "${archive_lines:-0}"
echo "  ─────────────────────────────────────────────────────────────"
printf "  %-40s %8s lines\n" "TOTAL (excluding .build/, .git/)" "$total_all"
echo ""
