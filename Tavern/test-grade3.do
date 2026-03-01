#!/bin/sh
# test-grade3.do - Run Grade 3 integration tests (real Claude API)
# These tests require Claude Code CLI to be installed and authenticated.
# Usage: redo test-grade3
#
# Claude-in-Claude safety:
#   - Strips CLAUDECODE env vars so spawned claude processes don't detect nesting
#   - Tracks SDK-spawned claude PIDs and kills orphans after test run
#   - Tests set permissionMode to prevent interactive prompts

redo-always

REPORT_DIR="$HOME/.local/builds/tavern/test-reports"
mkdir -p "$REPORT_DIR"

# --- Layer 2: PID tracking for orphan cleanup ---
# Snapshot existing claude SDK PIDs before test run (these are NOT ours)
PIDS_BEFORE=$(pgrep -f 'claude.*--input-format stream-json' 2>/dev/null || true)

# PID tracking file — poll during test run to catch short-lived processes too
PID_LOG="$REPORT_DIR/grade3-pids.log"
: > "$PID_LOG"

# Background PID tracker: polls every 2s and logs any new SDK-spawned claude PIDs
(
    while true; do
        pgrep -f 'claude.*--input-format stream-json' 2>/dev/null >> "$PID_LOG"
        sleep 2
    done
) &
TRACKER_PID=$!

# --- Layer 1: Strip Claude env vars + run tests ---
echo "Running Grade 3 integration tests (real Claude)..." >&2
env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT -u CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS \
    swift test --filter TavernIntegrationTests 2>&1 | tee "$REPORT_DIR/grade3-output.txt" >&2
TEST_EXIT=$?

# --- Layer 2: Orphan cleanup ---
# Stop the tracker
kill "$TRACKER_PID" 2>/dev/null || true
wait "$TRACKER_PID" 2>/dev/null || true

# Final snapshot
pgrep -f 'claude.*--input-format stream-json' 2>/dev/null >> "$PID_LOG"

# Kill any PIDs we tracked that weren't in the before-snapshot
ALL_TRACKED=$(sort -u "$PID_LOG")
KILLED=0
for pid in $ALL_TRACKED; do
    if ! echo "$PIDS_BEFORE" | grep -q "^${pid}$"; then
        if kill -0 "$pid" 2>/dev/null; then
            echo "Killing orphaned test claude process: $pid" >&2
            kill "$pid" 2>/dev/null || true
            KILLED=$((KILLED + 1))
        fi
    fi
done

if [ "$KILLED" -gt 0 ]; then
    echo "Cleaned up $KILLED orphaned claude process(es)" >&2
fi

rm -f "$PID_LOG"

if [ "$TEST_EXIT" -eq 0 ]; then
    echo "All Grade 3 integration tests passed" >&2
else
    echo "Integration tests failed — see $REPORT_DIR/grade3-output.txt" >&2
fi

exit $TEST_EXIT
