# lookagain

Sequential code review with fresh agent contexts. Each pass runs in an independent subagent, ensuring unbiased analysis that catches issues other passes might miss.

## Why?

A single code review pass catches ~60-70% of issues. Running multiple independent passes with fresh contexts significantly increases coverage. This plugin automates that workflow.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   /lookagain                        │
│                                                     │
│   ┌───────────────────────────────────────────┐    │
│   │          Orchestrator (main agent)         │    │
│   │                                            │    │
│   │  For each pass:                            │    │
│   │    1. Spawn subagent (fresh context)       │    │
│   │    2. Collect JSON findings                │    │
│   │    3. Apply must_fix auto-fixes            │    │
│   │                                            │    │
│   │  After all passes:                         │    │
│   │    - Deduplicate & score by confidence     │    │
│   │    - Save to .lookagain/                   │    │
│   └───────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
```

## Requirements

- [Claude Code](https://claude.ai/code)

## Installation

```bash
# Add the marketplace (if not already added)
/plugin marketplace add HartBrook/lookagain

# Install the plugin
/plugin install lookagain
```

## Usage

```bash
# Basic: 3 review passes with auto-fix for must_fix issues
/lookagain

# More passes for critical code
/lookagain passes=5

# Review specific directory
/lookagain target=src/auth

# Disable auto-fix (review only)
/lookagain auto-fix=false

# Increase max passes for stubborn issues
/lookagain passes=3 max-passes=10
```

## How It Works

1. **Pass 1**: Fresh subagent reviews code, outputs findings as JSON
2. **Fix**: Must-fix issues are automatically fixed (if auto-fix enabled)
3. **Pass 2**: New fresh subagent reviews (doesn't know what Pass 1 found)
4. **Fix**: Any new must-fix issues are fixed
5. **Pass 3**: Another fresh subagent reviews
6. **Aggregate**: Deduplicate findings, calculate confidence scores
7. **Report**: Summary with issues grouped by severity

Issues found by multiple passes have higher confidence scores.

## Output

Results are saved to `.lookagain/`:

- `aggregate.md` - Human-readable summary
- `aggregate.json` - Machine-readable findings
- `pass-N.json` - Raw output from each pass

## Configuration

Default behavior:

- 3 review passes
- Auto-fix must_fix issues
- Maximum 7 passes if must_fix issues persist
- Reviews current directory

## Severity Levels

| Severity   | Auto-fixed? | Examples                                        |
| ---------- | ----------- | ----------------------------------------------- |
| must_fix   | Yes         | Security vulns, runtime errors, data corruption |
| should_fix | No          | Performance issues, poor error handling         |
| suggestion | No          | Refactoring, documentation, style               |

## License

MIT
