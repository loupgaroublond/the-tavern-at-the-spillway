#!/bin/bash
# View Tavern logs filtered by category
# Usage: ./logs-category.sh <category> [minutes]
# Categories: agents, chat, coordination, claude, window

CATEGORY=$1
MINUTES=${2:-5}

if [ -z "$CATEGORY" ]; then
    echo "Usage: $0 <category> [minutes]"
    echo "Categories: agents, chat, coordination, claude, window"
    exit 1
fi

log show \
    --predicate "subsystem == 'com.tavern.spillway' AND category == '$CATEGORY'" \
    --last "${MINUTES}m" \
    --debug \
    --info \
    --style compact
