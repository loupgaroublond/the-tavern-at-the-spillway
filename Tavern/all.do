#!/bin/sh
# all.do - Default target: build and prepare for run
# Usage: redo all (or just: redo)

redo-ifchange build
echo "Build complete. Run with: redo run" >&2
