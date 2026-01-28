#!/bin/sh
# run.do - Kill existing Tavern and launch fresh build
# Usage: redo run

redo test
redo build

APP="$HOME/.local/builds/tavern/Build/Products/Debug/Tavern.app"

echo "Stopping existing Tavern instances..." >&2
pkill -f "Tavern.app" 2>/dev/null || true
sleep 0.5

if [ -d "$APP" ]; then
    echo "Launching $APP" >&2
    open "$APP"
else
    echo "Error: $APP not found" >&2
    exit 1
fi
