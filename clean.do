#!/bin/sh
# clean.do - Clean all build artifacts (project-wide)
# Usage: redo clean

redo-always

# Stop running app first
redo Tavern/stop

echo "Cleaning build artifacts..." >&2

# Derived data
DERIVED_DATA="$HOME/.local/builds/tavern"
if [ -d "$DERIVED_DATA" ]; then
    rm -rf "$DERIVED_DATA"
    echo "Removed $DERIVED_DATA" >&2
fi

# SPM build directories
for dir in Tavern/.build Tavern/LocalPackages/ClaudeCodeSDK/.build; do
    if [ -d "$dir" ]; then
        rm -rf "$dir"
        echo "Removed $dir" >&2
    fi
done

# redo state
for dir in .redo Tavern/.redo; do
    if [ -d "$dir" ]; then
        rm -rf "$dir"
        echo "Removed $dir" >&2
    fi
done

# Corrupted xcode projects (iCloud issue)
for proj in Tavern/"Tavern "[0-9]*.xcodeproj; do
    if [ -d "$proj" ]; then
        rm -rf "$proj"
        echo "Removed corrupted: $proj" >&2
    fi
done

echo "Clean complete" >&2
