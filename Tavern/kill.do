#!/bin/sh
# kill.do - Kill running Tavern instances
# Usage: redo kill

redo-always

echo "Killing Tavern instances..." >&2
pkill -f "Tavern.app" 2>/dev/null && echo "Killed" >&2 || echo "No instances running" >&2
