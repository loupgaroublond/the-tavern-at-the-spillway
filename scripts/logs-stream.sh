#!/bin/bash
# Stream Tavern logs in real-time
# Usage: ./logs-stream.sh [category]
# Categories: agents, chat, coordination, claude, window

CATEGORY=$1

if [ -n "$CATEGORY" ]; then
    log stream \
        --predicate "subsystem == 'com.tavern.spillway' AND category == '$CATEGORY'" \
        --level debug
else
    log stream \
        --predicate "subsystem == 'com.tavern.spillway'" \
        --level debug
fi
