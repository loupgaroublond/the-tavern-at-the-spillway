#!/bin/sh
# stop.do - Stop running Tavern instances
# Usage: redo Tavern/stop

redo-always

if pkill -f "Tavern.app" 2>/dev/null; then
    echo "Stopped Tavern" >&2
    sleep 0.5
else
    echo "No instances running" >&2
fi
