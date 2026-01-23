#!/bin/sh
# test.do - Run all tests
# Usage: redo test

redo-always

echo "Running all tests..." >&2
if swift test >&2; then
    echo "All tests passed" >&2
else
    echo "Tests failed" >&2
    exit 1
fi
