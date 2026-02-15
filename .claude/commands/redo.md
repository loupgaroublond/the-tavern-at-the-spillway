# Redo Build System Reference

Load this context when modifying .do files or debugging build issues.

## All .do Files and Their Dependencies

| File | Dependencies | redo-always? | Writes $3? |
|------|-------------|-------------|------------|
| `clean.do` (project root) | `Tavern/stop` | yes | no |
| `Tavern/all.do` | `build` | no | no |
| `Tavern/build.do` | `icon`, `xcodegen`, `project.yml`, `Package.swift` | no | no |
| `Tavern/icon.do` | `../scripts/generate_icon.py` | no | no |
| `Tavern/run.do` | `build` (via `redo`, not `redo-ifchange`) | no | no |
| `Tavern/stop.do` | (none) | yes | no |
| `Tavern/xcodegen.do` | `project.yml` | no | no |
| `Tavern/test.do` | (none) | yes | no |
| `Tavern/test-all.do` | (none) | yes | no |
| `Tavern/test-core.do` | (none) | yes | no |
| `Tavern/test-grade3.do` | (none) | yes | no |
| `Tavern/test-grade4.do` | `build` | yes | no |
| `Tavern/test-integration.do` | (none) | yes | no |

## Patterns in Use

**Virtual targets (no $3):** Every .do file in this project is a virtual target — side effects only, no output file. This means `redo-ifchange` is used for ordering/freshness, not for file production.

**Build log capture:** `build.do` captures xcodebuild output to a temp file, then `tail -20` on success or `tail -50` on failure. Follow this pattern for any new build scripts.

**Test isolation:** Test scripts use `swift test --skip` / `--filter` to isolate grades. All test targets use `redo-always`.

**stderr only:** All status messages go to `>&2`. Even though no script writes to `$3`, maintain this convention.

## When Modifying .do Files

- Use `redo-ifchange` for dependencies that can be checked by timestamp
- Use `redo-always` for targets where freshness can't be determined (tests, process checks)
- Use `set -e` and `set -o pipefail` for build scripts that must fail fast
- Keep the temp-file-then-tail pattern for verbose tool output
- Test reports go to `~/.local/builds/tavern/test-reports/`

## Redo Quick Reference

| Command | Purpose |
|---------|---------|
| `redo-ifchange targets...` | Declare dependency, build if stale |
| `redo-ifcreate files...` | Rebuild if file appears |
| `redo-always` | Always run this target |
| `redo-stamp < file` | Content-based change detection |
| `redo-whichdo target` | Show which .do handles a target |

Script params: `$1` = target path, `$2` = target without extension, `$3` = temp output file
