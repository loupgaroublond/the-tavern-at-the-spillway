#!/bin/bash
# View Tavern logs from the last N minutes (default: 5)
# Usage: ./logs.sh [minutes]

MINUTES=${1:-5}

log show \
    --predicate 'subsystem == "com.tavern.spillway"' \
    --last "${MINUTES}m" \
    --debug \
    --info \
    --style compact
