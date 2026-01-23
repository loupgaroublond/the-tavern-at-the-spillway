#!/bin/sh
# test-core.do - Run TavernCore unit tests only
# Usage: redo test-core

redo-always

echo "Running TavernCore tests..." >&2
if swift test --filter TavernCoreTests >&2; then
    echo "TavernCore tests passed" >&2
else
    echo "Tests failed" >&2
    exit 1
fi
