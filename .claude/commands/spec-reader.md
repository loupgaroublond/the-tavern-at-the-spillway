# Spec Reader — Compiled Active Specification

Compile all active spec modules into a single markdown file, stripping dropped sections.

## What To Do

Run the compilation script:

```bash
python3 scripts/compile-spec.py
```

This script:
1. Reads all spec modules from `docs/2-spec/` matching `NNN-*.md` (three-digit prefix)
2. Strips dropped sections in both formats:
   - `<!-- DROPPED ... -->` HTML comments (legacy)
   - `~~strikethrough~~` headings (current format per 000-index.md §5 — heading and all body content wrapped in `~~`, Status line unwrapped)
3. For each dropped section, removes the heading and all content until the next heading of equal or higher level
4. Compiles active content into `docs/2-spec/compiled/spec-reader_YYYY-MM-DD.md`

## After Running

Report the script's output:
- Total modules compiled
- Number of dropped sections skipped
- Output file path and size
