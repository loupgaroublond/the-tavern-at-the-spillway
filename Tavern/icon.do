#!/bin/sh
# icon.do - Generate app icons
# Usage: redo icon

# Depend on the generator script
redo-ifchange ../scripts/generate_icon.py

echo "Generating app icons..." >&2
uv run ../scripts/generate_icon.py >&2
