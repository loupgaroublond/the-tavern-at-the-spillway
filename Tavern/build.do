#!/bin/sh
# build.do - Build Tavern.app with xcodebuild
# Usage: redo build

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

# Build (all output to stderr)
echo "Building $SCHEME..." >&2
if xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -derivedDataPath "$DERIVED_DATA" \
    build >&2 2>&1 | tail -20 >&2
then
    echo "Build succeeded: $DERIVED_DATA/Build/Products/$CONFIG/Tavern.app" >&2
else
    echo "Build failed" >&2
    exit 1
fi
