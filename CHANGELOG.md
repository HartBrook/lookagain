# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.1] - 2026-05-12

### Changed

- Migrated `/look:again` and `/look:tidy` back from the `skills/` directory format to the `commands/` directory format so they appear under the `/look:` namespace in the slash command picker (matching the README) and surface their description chip when typed. The underlying multi-command misrouting bug that motivated the 0.4.0 migration was fixed upstream in Claude Code 2.1.101 (release notes: "Fixed several plugin issues: slash commands resolving to the wrong plugin with duplicate `name:` frontmatter ..."), so the workaround is no longer needed. As a defense-in-depth measure, the `name:` frontmatter field is now omitted from both command files - the slash name is derived from the filename, which removes any possibility of a duplicate-name collision regardless of the resolver version.
- The `lookagain-output-format` skill remains under `src/skills/` because the reviewer subagent invokes it via the Skill tool; it is not a user-facing slash command and would break if moved to `commands/`.
- Updated `scripts/test.sh`, `scripts/package.sh`, `evals/promptfooconfig.yaml`, and `CONTRIBUTING.md` to reflect the new file layout.

## [0.5.0] - 2026-05-12

### Added

- Global sequential numbering across all severity sections in `/look:again` aggregate summary tables, so issues can be referenced by ID (e.g. "fix #3, #5") across must_fix/should_fix/suggestion groups.
- "Suggested Fix" column in summary tables, providing a one-line fix preview alongside the existing detailed write-ups.
- Static format regression tests in `scripts/test.sh` enforcing the new numbering and Suggested Fix output contract.
- `.env` added to `.gitignore` so local `ANTHROPIC_API_KEY` files used for `make eval` / `make integration` cannot be committed accidentally.

### Changed

- Bumped promptfoo eval `max_tokens` to 4096 so reviewer outputs are not truncated mid-JSON for larger diffs.
- `/look:again` orchestrator and reviewer prompts updated to emphasize the global ID rules so passes produce stable, parseable output.
- Pipe and newline characters in Suggested Fix cells are now escaped so the markdown tables render correctly.

## [0.4.0] - 2026-01-29

### Changed

- Migrated commands from `commands/` directory to `skills/` directory format (`SKILL.md` files) to fix CLI command resolution issues on newer Claude Code versions. See [GSD plugin issue #218](https://github.com/glittercowboy/get-shit-done/issues/218) for background.
- Added `disable-model-invocation: true` to `/look:again` and `/look:tidy` to prevent unintended auto-invocation.
- Renamed frontmatter field `tools` to `allowed-tools` per skills format.
- Updated test suite, build script, evals, and documentation to reflect new file layout.
- No changes to user-facing command names: `/look:again` and `/look:tidy` work as before.

## [0.3.0] - 2026-01-28

### Changed

- **Breaking**: Replaced unsupported `arguments:` frontmatter array and `$ARGUMENTS.<name>` dot-access syntax with agent-side parsing of `$ARGUMENTS`. Claude Code only supports `$ARGUMENTS` (whole string) and `$ARGUMENTS[N]` (positional) — the named dot-access syntax was never interpolated, causing the agent to see literal placeholder text and fall back to safe defaults.
- Commands now include a "Parse arguments" section with a defaults table. The agent parses `key=value` pairs from the raw `$ARGUMENTS` string and applies documented defaults for missing keys.
- Commands log resolved configuration to make argument values visible and debuggable.
- Frontmatter uses `argument-hint` (supported) instead of `arguments:` (unsupported).
- Updated static tests to enforce the new pattern and reject the old `arguments:` frontmatter.
- Updated behavioral evals with new test cases for empty arguments (defaults) and partial arguments.
- Updated CONTRIBUTING.md prompt authoring guidance for the correct argument pattern.

## [0.2.1] - 2026-01-28

### Fixed

- Arguments like `auto-fix` now use `$ARGUMENTS.<name>` syntax at decision points in command prompts, not just in display sections. Previously, the executing agent could miss interpolated values and fall back to safe defaults (e.g., `auto-fix=false`).

### Added

- Behavioral evals via [promptfoo](https://promptfoo.dev) (`make eval`) that verify models correctly interpret argument values
- Static test (`test_argument_interpolation`) that enforces every frontmatter argument is referenced as `$ARGUMENTS.<name>` in the instruction body
- Contributing guide sections for running tests, setting `ANTHROPIC_API_KEY`, and writing command prompts

## [0.2.0] - 2026-01-28

### Added

- `/look:tidy` command for pruning old review runs
- Marketplace manifest (`.claude-plugin/marketplace.json`) for plugin discovery
- Target scope selection: `staged`, `commit`, `branch`, or a specific path
- Model selection: `thorough`, `balanced` (Sonnet), `fast` (Haiku)
- Marketplace install/test workflow in CONTRIBUTING guide

### Changed

- Streamlined reviewer agent prompt for clarity and focus
- Restructured `/look:again` command with clearer argument handling
- Expanded README with target scopes, model options, and tidy usage
- Hardened `test.sh` with marketplace manifest validation

## [0.1.0] - 2026-01-26

### Added

- Initial release of lookagain plugin
- Multi-pass code review with fresh agent contexts
- Configurable number of passes (default: 3)
- Auto-fix for must_fix severity issues
- Severity levels: must_fix, should_fix, suggestion
- Confidence scoring based on cross-pass detection
- JSON and markdown output reports
- Target directory/file selection
- Maximum passes cap to prevent infinite loops
