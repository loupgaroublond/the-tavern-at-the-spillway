#!/bin/sh
# test.do - Run Grade 1+2 tests (unit tests with/without mocks)
# Skips integration tests (Grade 3) and stress tests (Grade 5)
# Usage: redo test

redo-always

REPORT_DIR="$HOME/.local/builds/tavern/test-reports"
mkdir -p "$REPORT_DIR"

echo "Running Grade 1+2 tests..." >&2
swift test --skip TavernIntegrationTests --skip TavernStressTests >"$REPORT_DIR/grade1-2-output.txt" 2>&1
TEST_EXIT=$?
if [ $TEST_EXIT -eq 0 ]; then
    echo "All Grade 1+2 tests passed" >&2
else
    echo "Tests failed — see $REPORT_DIR/grade1-2-output.txt" >&2
    tail -20 "$REPORT_DIR/grade1-2-output.txt" | LC_ALL=C tr -cd '[:print:]\n' >&2
    exit 1
fi
