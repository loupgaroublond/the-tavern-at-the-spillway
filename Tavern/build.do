#!/bin/sh
# build.do - Build Tavern.app with xcodebuild
# Usage: redo build

set -e  # Exit on any error
set -o pipefail  # Pipeline fails if any command fails

# Ensure icon and xcodegen are up to date first
redo-ifchange icon xcodegen

# Build configuration
DERIVED_DATA="$HOME/.local/builds/tavern"
PROJECT="Tavern.xcodeproj"
SCHEME="Tavern"
CONFIG="Debug"

# Create derived data directory if needed
mkdir -p "$DERIVED_DATA"

# Declare dependencies on key configuration files
redo-ifchange project.yml Package.swift

# Build (capture output, check exit status properly)
echo "Building $SCHEME..." >&2
BUILD_LOG=$(mktemp)
if xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -derivedDataPath "$DERIVED_DATA" \
    build >"$BUILD_LOG" 2>&1
then
    tail -20 "$BUILD_LOG" >&2
    echo "Build succeeded: $DERIVED_DATA/Build/Products/$CONFIG/Tavern.app" >&2
    rm -f "$BUILD_LOG"
else
    EXIT_CODE=$?
    echo "=== BUILD FAILED ===" >&2
    tail -50 "$BUILD_LOG" >&2
    rm -f "$BUILD_LOG"
    exit $EXIT_CODE
fi
