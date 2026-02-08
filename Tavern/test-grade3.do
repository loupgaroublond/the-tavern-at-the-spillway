#!/bin/sh
# test-grade3.do - Run Grade 3 integration tests (real Claude API)
# These tests require Claude Code CLI to be installed and authenticated.
# Usage: redo test-grade3

redo-always

REPORT_DIR="$HOME/.local/builds/tavern/test-reports"
mkdir -p "$REPORT_DIR"

echo "Running Grade 3 integration tests (real Claude)..." >&2
if swift test --filter TavernIntegrationTests 2>&1 | tee "$REPORT_DIR/grade3-output.txt" >&2; then
    echo "All Grade 3 integration tests passed" >&2
else
    echo "Integration tests failed — see $REPORT_DIR/grade3-output.txt" >&2
    exit 1
fi
