#!/bin/sh
# test-integration.do - Run TavernTests integration tests only
# Usage: redo test-integration

redo-always

echo "Running integration tests..." >&2
if swift test --filter TavernTests >&2; then
    echo "Integration tests passed" >&2
else
    echo "Tests failed" >&2
    exit 1
fi
