#!/bin/sh
# xcodegen.do - Regenerate Xcode project from project.yml
# Usage: redo xcodegen

redo-ifchange project.yml

echo "Regenerating Xcode project..." >&2
xcodegen generate >&2
echo "Xcode project regenerated" >&2
