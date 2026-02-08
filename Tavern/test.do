#!/bin/sh
# test.do - Run Grade 1+2 tests (unit tests with/without mocks)
# Skips integration tests (Grade 3) and stress tests (Grade 5)
# Usage: redo test

redo-always

REPORT_DIR="$HOME/.local/builds/tavern/test-reports"
mkdir -p "$REPORT_DIR"

echo "Running Grade 1+2 tests..." >&2
if swift test --skip TavernIntegrationTests --skip TavernStressTests 2>&1 | tee "$REPORT_DIR/grade1-2-output.txt" >&2; then
    echo "All Grade 1+2 tests passed" >&2
else
    echo "Tests failed — see $REPORT_DIR/grade1-2-output.txt" >&2
    exit 1
fi
