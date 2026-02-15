# Redo Build System Patterns Guide

A guide to using the redo build system, adapted for the Tavern project's Swift/SwiftUI/Xcode build pipeline. Covers standard `.do` scripts, dependency declaration, and the project's specific build patterns.

## Table of Contents

1. [Introduction to Redo](#introduction-to-redo)
2. [Core Concepts](#core-concepts)
3. [Script Parameters](#script-parameters)
4. [Script Search Algorithm](#script-search-algorithm)
5. [Dependency Declaration](#dependency-declaration)
6. [Tavern Project Layout](#tavern-project-layout)
7. [Common Patterns](#common-patterns)
8. [Common Workflows](#common-workflows)
9. [Redoconf and .od Files](#redoconf-and-od-files)
10. [Best Practices](#best-practices)
11. [Quick Reference](#quick-reference)


## Introduction to Redo

Redo is a recursive, general-purpose build system created by D. J. Bernstein and implemented by Avery Pennarun. Unlike `make`, redo uses simple shell scripts (`.do` files) with no special syntax.

**Key advantages:**

- No special syntax to learn — just shell scripts

- Automatic dependency tracking

- Parallel builds with proper job control

- Incremental rebuilds based on file changes

- Recursive dependency resolution


## Core Concepts

### Targets and Scripts

Every file you want to build is a **target**. To build a target, redo looks for a matching `.do` script and executes it.

```
target.ext  →  built by  →  target.ext.do (specific)
                     or  →  default.ext.do (generic)
                     or  →  default.do (fallback)
```

### Source vs Derived Materials

- **Source materials**: Human-written files (code, configs, docs)

- **Derived materials**: Machine-generated files (compiled objects, Xcode projects, app bundles)

Redo helps enforce this distinction — derived files can be deleted and regenerated, source files cannot. In the Tavern project, `Tavern.xcodeproj` is derived (from `project.yml`), while Swift source files and `Package.swift` are source materials.


## Script Parameters

Every `.do` script receives three positional parameters:

| Parameter | Description | Example |
|-----------|-------------|---------|
| `$1` | Full target name (with path) | `Tavern/build` |
| `$2` | Target basename without extension | `Tavern/build` |
| `$3` | Temporary output file | `/tmp/redo.xxxxx.tmp` |

**Critical rule**: Write your output to `$3`, not directly to `$1`. Redo atomically moves `$3` to `$1` only if the script succeeds.

### Virtual Targets

Most Tavern `.do` scripts are **virtual targets** — they perform side effects (build the app, run tests, stop processes) and produce no output file. They never write to `$3`. This is a valid and common redo pattern for task-runner style usage.


## Script Search Algorithm

When you run `redo path/to/target.a.b.c`, redo searches for scripts in this order:

```
1. path/to/target.a.b.c.do    (exact match)
2. path/to/default.a.b.c.do   (extension chain)
3. path/to/default.b.c.do
4. path/to/default.c.do
5. path/to/default.do
6. path/default.a.b.c.do      (parent directory)
7. path/default.b.c.do
... and so on up to project root
```

### Using `redo-whichdo`

To see which script handles a target:

```sh
$ redo-whichdo Tavern/build
Tavern/build.do (would use)  ← exact match
```


## Dependency Declaration

### `redo-ifchange` — The Core Command

Declares dependencies and builds them if needed:

```sh
#!/bin/sh
# build.do

# Declare dependencies - builds them if out of date
redo-ifchange icon xcodegen

# Also depend on configuration files
redo-ifchange project.yml Package.swift

# Build...
xcodebuild ...
```

**Key behaviors:**

- If any dependency is out of date, it's rebuilt first

- Multiple targets can be listed for parallel builds

- Dependencies can be declared at any point in the script

- Post-build dependencies work (declare after building)

### `redo-ifcreate` — Missing File Dependencies

Triggers rebuild if a file is **created**:

```sh
#!/bin/sh
# config.do

# Rebuild if optional.conf appears
redo-ifcreate optional.conf

if [ -f optional.conf ]; then
    cat optional.conf > "$3"
else
    echo "defaults" > "$3"
fi
```

### `redo-always` — Force Rebuild

Marks target as always out of date. Used for targets where freshness can't be determined from file timestamps — tests, process management, cleanup:

```sh
#!/bin/sh
# test.do

redo-always  # Tests should always run when requested
swift test --skip TavernIntegrationTests >&2
```

```sh
#!/bin/sh
# stop.do

redo-always  # Always check for running processes
pkill -f "Tavern.app" 2>/dev/null || true
```

### `redo-stamp` — Content-Based Rebuilds

Prevents unnecessary rebuilds when output hasn't changed:

```sh
#!/bin/sh
# file-list.do

redo-always  # Generate list every time
find src -name "*.swift" | sort > "$3"

# But only trigger dependents if content changed
redo-stamp < "$3"
```


## Tavern Project Layout

The project has 13 `.do` files across two directories:

```
the-tavern-at-the-spillway/
├── clean.do                  # Project-wide clean (stops app, removes all artifacts)
└── Tavern/
    ├── all.do                # Default target: build and report
    ├── build.do              # xcodebuild with log capture
    ├── icon.do               # Generate app icons (Python via uv)
    ├── run.do                # Build → kill existing → launch app
    ├── stop.do               # Kill running Tavern instances
    ├── xcodegen.do           # Regenerate .xcodeproj from project.yml
    ├── test.do               # Grade 1+2 tests (unit + mock)
    ├── test-all.do           # Grade 1+2+3 tests (adds real Claude)
    ├── test-core.do          # TavernCore tests only
    ├── test-grade3.do        # Grade 3 integration tests only
    ├── test-grade4.do        # Grade 4 XCUITest (steals focus!)
    └── test-integration.do   # TavernTests (wiring + SDK) only
```

### Dependency Graph

```
run ──→ build ──→ icon ──→ ../scripts/generate_icon.py
                  ├────→ xcodegen ──→ project.yml
                  ├────→ project.yml
                  └────→ Package.swift

test-grade4 ──→ build

all ──→ build

clean ──→ Tavern/stop
```

### Build Output Paths

All build output goes to `~/.local/builds/tavern/` rather than the project directory. This avoids iCloud sync interference — the project lives in `~/Documents` which iCloud syncs, and Xcode's derived data plus code signing don't survive iCloud's conflict resolution.

| Path | Contents |
|------|----------|
| `~/.local/builds/tavern/Build/Products/Debug/Tavern.app` | The built application |
| `~/.local/builds/tavern/test-reports/` | Test output logs |
| `~/.local/builds/tavern/test-reports/grade1-2-output.txt` | Grade 1+2 test results |
| `~/.local/builds/tavern/test-reports/grade3-output.txt` | Grade 3 test results |
| `~/.local/builds/tavern/test-reports/grade4-output.txt` | Grade 4 test results |


## Common Patterns

### Pattern: Virtual Targets (No Output File)

Most Tavern `.do` scripts are virtual — they perform actions but produce no file. The key signal is that they never write to `$3`:

```sh
#!/bin/sh
# run.do - Build, kill existing, launch fresh

redo build

APP="$HOME/.local/builds/tavern/Build/Products/Debug/Tavern.app"

echo "Stopping existing Tavern instances..." >&2
pkill -f "Tavern.app" 2>/dev/null || true
sleep 0.5

if [ -d "$APP" ]; then
    echo "Launching $APP" >&2
    open "$APP"
else
    echo "Error: $APP not found" >&2
    exit 1
fi
```

Note `run.do` uses `redo build` (unconditional) rather than `redo-ifchange build`. Since `run` is itself a virtual target with no output file, the dependency tracking semantics don't matter — you always want a fresh build when you say `redo run`.

### Pattern: Dependency Chains

`build.do` declares dependencies on other virtual targets (`icon`, `xcodegen`) and on source files (`project.yml`, `Package.swift`). This creates a chain:

```sh
#!/bin/sh
# build.do

set -e
set -o pipefail

# Virtual target dependencies — rebuild icon and xcodegen if their inputs changed
redo-ifchange icon xcodegen

# Source file dependencies — rebuild if config changes
redo-ifchange project.yml Package.swift

# The actual build
xcodebuild -project Tavern.xcodeproj -scheme Tavern ...
```

When you run `redo build`:
1. Redo checks if `icon` is up to date (depends on `generate_icon.py`)
2. Redo checks if `xcodegen` is up to date (depends on `project.yml`)
3. Redo checks if `project.yml` or `Package.swift` changed
4. Only if something changed does xcodebuild run

### Pattern: Build Log Capture

`build.do` captures xcodebuild's verbose output to a temp file, then tails the last N lines on success or last 50 on failure. This keeps the terminal clean while preserving full diagnostics:

```sh
BUILD_LOG=$(mktemp)
if xcodebuild ... >"$BUILD_LOG" 2>&1
then
    tail -20 "$BUILD_LOG" >&2        # Show last 20 lines on success
    echo "Build succeeded: ..." >&2
    rm -f "$BUILD_LOG"
else
    EXIT_CODE=$?
    echo "=== BUILD FAILED ===" >&2
    tail -50 "$BUILD_LOG" >&2        # Show last 50 lines on failure
    rm -f "$BUILD_LOG"
    exit $EXIT_CODE
fi
```

**Why this matters:** xcodebuild produces thousands of lines. Without capture, the useful information scrolls off screen. The temp-file-then-tail pattern gives you just the summary on success and enough context on failure.

### Pattern: Test Grade Isolation

The test `.do` files use `swift test --skip` and `--filter` flags to isolate test grades. This maps the project's [five-grade test system](../3-adr/ADR-002-testing-grades.md) onto redo targets:

```sh
# test.do — Grade 1+2 (safe to run anytime)
swift test --skip TavernIntegrationTests --skip TavernStressTests

# test-core.do — Just TavernCore
swift test --filter TavernCoreTests

# test-grade3.do — Real Claude API calls
swift test --filter TavernIntegrationTests

# test-all.do — Runs test.do then test-grade3.do sequentially
```

All test targets use `redo-always` because tests should run every time they're requested, regardless of file timestamps. Test output is tee'd to report files under `~/.local/builds/tavern/test-reports/`.

### Pattern: Cleanup with Artifact Categories

`clean.do` at the project root removes multiple categories of artifacts, with status messages for each:

```sh
#!/bin/sh
# clean.do

redo-always

# Stop the app first (dependency on another virtual target)
redo Tavern/stop

# Category 1: Build output
rm -rf "$HOME/.local/builds/tavern"

# Category 2: SPM build directories
rm -rf Tavern/.build

# Category 3: Redo state
rm -rf .redo Tavern/.redo

# Category 4: Corrupted Xcode projects (iCloud artifact)
rm -rf Tavern/"Tavern "[0-9]*.xcodeproj
```

The iCloud cleanup glob (`"Tavern "[0-9]*.xcodeproj`) catches numbered copies like `Tavern 5.xcodeproj` that iCloud creates during sync conflicts.

### Pattern: Status Messages to stderr

Every `.do` script sends progress messages to stderr (`>&2`). This keeps stdout clean — stdout is reserved for the output file (`$3`). Even virtual targets that don't write to `$3` follow this convention for consistency:

```sh
echo "Running Grade 1+2 tests..." >&2
if swift test ... >&2; then
    echo "All Grade 1+2 tests passed" >&2
else
    echo "Tests failed — see $REPORT_DIR/grade1-2-output.txt" >&2
    exit 1
fi
```


## Common Workflows

### Build and Launch

```sh
redo Tavern/run        # Build → stop existing → launch
```

### Run Tests After a Change

```sh
redo Tavern/test       # Grade 1+2 (fast, safe, no API calls)
redo Tavern/test-core  # Just TavernCore if that's all you touched
```

### Full Test Suite

```sh
redo Tavern/test-all   # Grade 1+2+3 (includes real Claude API)
```

### Clean Rebuild

```sh
redo clean             # Remove everything (stops app first)
redo Tavern/run        # Full rebuild from scratch
```

### After Editing project.yml

```sh
redo Tavern/xcodegen   # Regenerate .xcodeproj
redo Tavern/build      # Rebuild with new project config
```

### Regenerate App Icon

```sh
redo Tavern/icon       # Runs generate_icon.py via uv
redo Tavern/build      # Rebuild to pick up new icon
```


## Redoconf and .od Files

Redoconf extends redo for **cross-platform, out-of-tree builds**. It introduces `.od` files for platform-specific compilation. The Tavern project doesn't use redoconf (it builds with Xcode for macOS only), but this section is included as reference for compiled-language projects.

### The Problem Redoconf Solves

Standard redo puts output files next to source files. But for cross-compilation:

- You want multiple output directories (one per platform)

- You can't put `.do` files in output directories (not in source control)

- You need platform-specific build logic

### .do vs .od Files

| Aspect | `.do` Files | `.od` Files |
|--------|-------------|-------------|
| Purpose | Source targets | Output targets |
| Location | Source tree | Source tree |
| Output | Same directory as script | Platform-specific output dir |
| Use case | Generate source files | Compile/link binaries |

### How .od Files Work

```
Source Tree                    Output Tree (out.linux-x64/)
├── main.c                     ├── main.o        ← built by main.o.od
├── main.o.od                  ├── program       ← built by program.od
├── program.od                 └── ...
└── default.do
```

`.od` files live in the source tree but specify how to build targets in the output tree.

### Redoconf Example

**Build script: `default.o.od`**
```sh
#!/bin/sh
# default.o.od - Compile any .cpp to .o (cross-platform)

set -e
. ./redoconf.rc && . rc/CXX.rc

SRC="$SRCDIR/${2##*/}.cpp"
redo-ifchange "$SRC"

$CXX $CXXFLAGS $CPPFLAGS -c -o "$3" "$SRC"
```

**Key differences from `.do`:**

1. Source `redoconf.rc` for build environment

2. Use `$SRCDIR` to reference source files

3. Use variables (`$CXX`, `$CFLAGS`) instead of hardcoded values

4. Basename extraction with `${2##*/}` for source lookup

### Running Redoconf Builds

```sh
# Configure for current platform
./configure

# Build in output directory
cd out && redo all

# Cross-compile for Windows
mkdir out.mingw && cd out.mingw
../configure --host=x86_64-w64-mingw32
redo all
```


## Best Practices

### 1. Always Use `$3` for Output

```sh
# ✓ Correct - atomic replacement
echo "content" > "$3"

# ✗ Wrong - not atomic, no error handling
echo "content" > "$1"
```

### 2. Declare Dependencies Before Using Them

```sh
# ✓ Correct
redo-ifchange project.yml
xcodegen generate

# ✗ Wrong - might use stale project.yml
xcodegen generate
redo-ifchange project.yml  # Too late!
```

### 3. Use stderr for Status Messages

```sh
# ✓ Correct - stdout clean for output
echo "Building..." >&2
xcodebuild ... >"$BUILD_LOG" 2>&1

# ✗ Wrong - pollutes output
echo "Building..."  # Goes to $3!
```

### 4. Handle Spaces in Filenames

```sh
# ✓ Correct - quoted
redo-ifchange "$SOURCE"

# ✗ Wrong - breaks on spaces
redo-ifchange $SOURCE
```

### 5. Use Subshells for Directory Changes

```sh
# ✓ Correct - contained directory change
(cd "$DIR" && make all) >&2

# ✗ Risky - affects subsequent commands
cd "$DIR"
make all >&2
```

### 6. Fail Fast with `set -e`

```sh
#!/bin/sh
set -e          # Exit on first error
set -o pipefail # Pipeline fails if any command fails

redo-ifchange deps
step_one
step_two    # Won't run if step_one fails
```

### 7. Use `redo-always` for Side-Effect Targets

Targets that check process state, run tests, or perform cleanup should always run when requested:

```sh
#!/bin/sh
# stop.do
redo-always  # Always check - can't know from timestamps if app is running
pkill -f "Tavern.app" 2>/dev/null || true
```

### 8. Keep Scripts Generic When Possible

Prefer `default.ext.do` over specific scripts when the logic is the same across targets. In the Tavern project, each target has specific-enough logic to warrant its own script, but for projects with many similar targets (compiling C files, transforming configs), generic scripts save duplication.


## Quick Reference

### Redo Commands

| Command | Purpose |
|---------|---------|
| `redo target` | Build target (always) |
| `redo-ifchange targets...` | Build if out of date, declare dependency |
| `redo-ifcreate files...` | Rebuild if file created |
| `redo-always` | Mark current target always dirty |
| `redo-stamp < file` | Use content hash for change detection |
| `redo-whichdo target` | Show which .do script handles target |
| `redo-targets` | List all known targets |
| `redo-sources` | List all known sources |
| `redo-ood` | List out-of-date targets |

### Script Parameters

| Parameter | Contains |
|-----------|----------|
| `$1` | Full target path |
| `$2` | Target path without extension |
| `$3` | Temporary output file |

### Tavern Build Targets

| Target | Command | What It Does |
|--------|---------|-------------|
| `clean` | `redo clean` | Stop app, remove all artifacts |
| `Tavern/all` | `redo Tavern/all` (or `cd Tavern && redo`) | Build only |
| `Tavern/build` | `redo Tavern/build` | xcodebuild with dependencies |
| `Tavern/icon` | `redo Tavern/icon` | Generate app icons |
| `Tavern/run` | `redo Tavern/run` | Build → kill → launch |
| `Tavern/stop` | `redo Tavern/stop` | Kill running instances |
| `Tavern/xcodegen` | `redo Tavern/xcodegen` | Regenerate .xcodeproj |
| `Tavern/test` | `redo Tavern/test` | Grade 1+2 tests |
| `Tavern/test-all` | `redo Tavern/test-all` | Grade 1+2+3 tests |
| `Tavern/test-core` | `redo Tavern/test-core` | TavernCore only |
| `Tavern/test-grade3` | `redo Tavern/test-grade3` | Integration (real Claude) |
| `Tavern/test-grade4` | `redo Tavern/test-grade4` | XCUITest (steals focus!) |
| `Tavern/test-integration` | `redo Tavern/test-integration` | TavernTests only |

### Naming Conventions

| Pattern | Use Case |
|---------|----------|
| `target.do` | Specific target script |
| `default.ext.do` | Generic handler for `.ext` files |
| `default.do` | Fallback handler |
| `all.do` | Build everything (default target) |
| `clean.do` | Remove derived files |
| `test.do` | Run tests |
| `run.do` | Build and launch |
| `stop.do` | Kill running processes |


## Further Reading

- [Redo Documentation](https://redo.readthedocs.io/)

- [apenwarr/redo on GitHub](https://github.com/apenwarr/redo)

- [D. J. Bernstein's Original Redo Concept](http://cr.yp.to/redo.html)

- [Redoconf Cookbook](https://redo.readthedocs.io/en/latest/cookbook/redoconf-simple/)
