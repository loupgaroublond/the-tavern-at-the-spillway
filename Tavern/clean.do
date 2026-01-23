#!/bin/sh
# clean.do - Clean build artifacts
# Usage: redo clean

redo-always

echo "Cleaning build artifacts..." >&2

DERIVED_DATA="$HOME/.local/builds/tavern"
if [ -d "$DERIVED_DATA" ]; then
    rm -rf "$DERIVED_DATA"
    echo "Removed $DERIVED_DATA" >&2
fi

if [ -d ".build" ]; then
    rm -rf .build
    echo "Removed .build/" >&2
fi

if [ -d ".redo" ]; then
    rm -rf .redo
    echo "Removed .redo/" >&2
fi

for proj in "Tavern "[0-9]*.xcodeproj; do
    if [ -d "$proj" ]; then
        rm -rf "$proj"
        echo "Removed corrupted: $proj" >&2
    fi
done

echo "Clean complete" >&2
