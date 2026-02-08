#!/bin/sh
# test-all.do - Run Grade 1+2+3 tests (full headless suite)
# Usage: redo test-all

redo-always

REPORT_DIR="$HOME/.local/builds/tavern/test-reports"
mkdir -p "$REPORT_DIR"

echo "Running Grade 1+2 tests..." >&2
if swift test --skip TavernIntegrationTests --skip TavernStressTests 2>&1 | tee "$REPORT_DIR/grade1-2-output.txt" >&2; then
    echo "Grade 1+2 tests passed" >&2
else
    echo "Grade 1+2 tests failed — see $REPORT_DIR/grade1-2-output.txt" >&2
    exit 1
fi

echo "" >&2
echo "Running Grade 3 integration tests (real Claude)..." >&2
if swift test --filter TavernIntegrationTests 2>&1 | tee "$REPORT_DIR/grade3-output.txt" >&2; then
    echo "Grade 3 integration tests passed" >&2
else
    echo "Grade 3 integration tests failed — see $REPORT_DIR/grade3-output.txt" >&2
    exit 1
fi

echo "" >&2
echo "All Grade 1+2+3 tests passed" >&2
