# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
