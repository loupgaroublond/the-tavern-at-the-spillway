#!/usr/bin/env python3
"""Compile all active spec modules into a single markdown file, stripping DROPPED sections."""

import os
import re
import glob
import sys
from datetime import datetime


def compile_spec(spec_dir, output_path=None):
    """Compile spec modules, stripping DROPPED sections.

    Args:
        spec_dir: Path to docs/2-spec/
        output_path: Output file path. If None, auto-generates with current date.

    Returns:
        dict with stats: modules, dropped_count, output_path, size_kb
    """
    output_dir = os.path.join(spec_dir, "compiled")
    os.makedirs(output_dir, exist_ok=True)

    if output_path is None:
        today = datetime.now().strftime("%Y-%m-%d")
        output_path = os.path.join(output_dir, f"spec-reader_{today}.md")

    # Find all NNN-*.md files
    pattern = os.path.join(spec_dir, "[0-9][0-9][0-9]-*.md")
    files = sorted(glob.glob(pattern))

    modules = []
    dropped_count = 0

    for fpath in files:
        fname = os.path.basename(fpath)
        num = fname[:3]

        with open(fpath, "r") as f:
            content = f.read()

        # Extract title from first line (# NNN — Title)
        first_line = content.split("\n")[0]
        title_match = re.match(r"^#\s+\d+\s*[—–-]\s*(.+)$", first_line)
        if title_match:
            title = title_match.group(1).strip()
        else:
            title = fname.replace(".md", "")

        # Strip DROPPED sections
        lines = content.split("\n")
        filtered_lines = []
        skip_until_level = None
        i = 0
        while i < len(lines):
            line = lines[i]

            # Check if this line has a DROPPED marker
            if "<!-- DROPPED" in line:
                # Determine the heading level of the dropped section
                heading_match = re.search(r"(#{1,6})\s", line)
                if heading_match:
                    drop_level = len(heading_match.group(1))
                    skip_until_level = drop_level
                    dropped_count += 1
                    i += 1
                    continue
                else:
                    # DROPPED comment without heading on same line
                    # Check if next line is a heading
                    if i + 1 < len(lines):
                        next_line = lines[i + 1]
                        next_heading = re.match(r"^(#{1,6})\s", next_line)
                        if next_heading:
                            drop_level = len(next_heading.group(1))
                            skip_until_level = drop_level
                            dropped_count += 1
                            i += 2  # skip both lines
                            continue
                    # Just skip the comment line
                    i += 1
                    continue

            # If we're skipping, check if we've reached a heading of equal or higher level
            if skip_until_level is not None:
                heading_match = re.match(r"^(#{1,6})\s", line)
                if heading_match:
                    level = len(heading_match.group(1))
                    if level <= skip_until_level:
                        skip_until_level = None
                        filtered_lines.append(line)
                        i += 1
                        continue
                i += 1
                continue

            filtered_lines.append(line)
            i += 1

        # Remove the first line (original title) since we add our own section header
        content_without_title = "\n".join(filtered_lines[1:]).strip()

        modules.append(
            {
                "num": num,
                "title": title,
                "content": content_without_title,
            }
        )

    # Build output
    out = []
    out.append("# Tavern at the Spillway — Compiled Specification")
    out.append(f"**Generated:** {datetime.now().strftime('%Y-%m-%d')}")
    out.append(f"**Source modules:** §000–§{modules[-1]['num']}")
    out.append(f"**Active modules:** {len(modules)}")
    out.append(f"**Dropped sections stripped:** {dropped_count}")
    out.append("")
    out.append("## Table of Contents")
    out.append("")
    for m in modules:
        anchor = m["title"].lower().replace(" ", "-").replace("/", "").replace("&", "")
        out.append(f"- [§{m['num']} — {m['title']}](#§{m['num']}--{anchor})")
    out.append("")

    for m in modules:
        out.append("---")
        out.append("")
        out.append(f"# §{m['num']} — {m['title']}")
        out.append("")
        out.append(m["content"])
        out.append("")

    result = "\n".join(out)

    with open(output_path, "w") as f:
        f.write(result)

    size_kb = os.path.getsize(output_path) / 1024
    return {
        "modules": len(modules),
        "dropped_count": dropped_count,
        "output_path": output_path,
        "size_kb": size_kb,
    }


if __name__ == "__main__":
    # Default: run from project root
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    spec_dir = os.path.join(project_root, "docs", "2-spec")

    if not os.path.isdir(spec_dir):
        print(f"Error: spec directory not found at {spec_dir}", file=sys.stderr)
        sys.exit(1)

    stats = compile_spec(spec_dir)
    print(f"Total modules compiled: {stats['modules']}")
    print(f"Dropped sections stripped: {stats['dropped_count']}")
    print(f"Output: {stats['output_path']}")
    print(f"Size: {stats['size_kb']:.1f} KB")
