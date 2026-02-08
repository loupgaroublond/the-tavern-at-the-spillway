#!/bin/sh
# test-grade4.do - Run Grade 4 XCUITest tests (requires dedicated environment)
# These tests steal focus — run when user is not actively using the app.
# Usage: redo test-grade4

redo-always

# Ensure project is built and up to date
redo-ifchange build

DERIVED_DATA="$HOME/.local/builds/tavern"
REPORT_DIR="$HOME/.local/builds/tavern/test-reports"
PROJECT="Tavern.xcodeproj"
SCHEME="Tavern"

mkdir -p "$REPORT_DIR"

echo "Running Grade 4 XCUITest tests (steals focus)..." >&2
if xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -derivedDataPath "$DERIVED_DATA" \
    -only-testing:TavernUITests \
    2>&1 | tee "$REPORT_DIR/grade4-output.txt" >&2; then
    echo "All Grade 4 XCUITest tests passed" >&2
else
    echo "XCUITest tests failed — see $REPORT_DIR/grade4-output.txt" >&2
    exit 1
fi
