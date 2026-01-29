# lookagain

Sequential code review with fresh agent contexts. Each pass runs in an independent subagent, ensuring unbiased analysis that catches issues other passes might miss.

## Why?

A single code review pass catches ~60-70% of issues. Running multiple independent passes with fresh contexts significantly increases coverage. This plugin automates that workflow.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   /look:again                       │
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
# Add the marketplace
/plugin marketplace add HartBrook/lookagain

# Install the plugin
/plugin install look@hartbrook-plugins
```

## Usage

```bash
# Review staged changes (default)
/look:again

# Review the last commit
/look:again target=commit

# Review all changes on the current branch
/look:again target=branch

# Review a specific directory
/look:again target=src/auth

# More passes for critical code
/look:again passes=5

# Use a faster, cheaper model for reviewers
/look:again model=fast

# Balanced cost/quality
/look:again model=balanced

# Disable auto-fix (review only)
/look:again auto-fix=false

# Combine options
/look:again target=branch passes=5 model=fast
```

### Target Scopes

| Target | What gets reviewed |
| --- | --- |
| `staged` (default) | Files in the git staging area |
| `commit` | Files changed in the last commit |
| `branch` | All changes on the current branch vs base |
| `<path>` | Files in the given directory or path |

### Model Options

| Model | Engine | Best for |
| --- | --- | --- |
| `thorough` (default) | Inherits current model | Critical code, security-sensitive reviews |
| `balanced` | Sonnet | Good balance of cost and quality |
| `fast` | Haiku | Quick checks, large codebases, cost-conscious usage |

## How It Works

1. **Pass 1**: Fresh subagent reviews scoped changes, outputs findings as JSON
2. **Fix**: Must-fix issues are automatically fixed (if auto-fix enabled)
3. **Pass 2**: New fresh subagent reviews (doesn't know what Pass 1 found)
4. **Fix**: Any new must-fix issues are fixed
5. **Pass 3**: Another fresh subagent reviews
6. **Aggregate**: Deduplicate findings, calculate confidence scores
7. **Report**: Summary with issues grouped by severity

Issues found by multiple passes have higher confidence scores.

## Output

Each run saves results to a timestamped directory `.lookagain/<run-id>/`:

- `aggregate.md` - Human-readable summary
- `aggregate.json` - Machine-readable findings
- `pass-N.json` - Raw output from each pass

Previous runs are preserved. Use `/look:tidy` to prune old results:

```bash
# Remove runs older than 1 day (default)
/look:tidy

# Keep last 3 days
/look:tidy keep=3

# Remove all runs
/look:tidy all=true
```

## Configuration

| Argument | Default | Description |
| --- | --- | --- |
| `passes` | `3` | Number of review passes |
| `target` | `staged` | What to review: `staged`, `commit`, `branch`, or a path |
| `auto-fix` | `true` | Auto-fix `must_fix` issues between passes |
| `model` | `thorough` | Reviewer model: `fast`, `balanced`, `thorough` |
| `max-passes` | `7` | Max passes if `must_fix` issues persist |

## Severity Levels

| Severity   | Auto-fixed? | Examples                                        |
| ---------- | ----------- | ----------------------------------------------- |
| must_fix   | Yes         | Security vulns, runtime errors, data corruption |
| should_fix | No          | Performance issues, poor error handling         |
| suggestion | No          | Refactoring, documentation, style               |

## License

MIT
