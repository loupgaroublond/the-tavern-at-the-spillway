#!/bin/bash
# View only error-level Tavern logs
# Usage: ./logs-errors.sh [minutes]

MINUTES=${1:-30}

log show \
    --predicate "subsystem == 'com.tavern.spillway' AND messageType == error" \
    --last "${MINUTES}m" \
    --style compact
