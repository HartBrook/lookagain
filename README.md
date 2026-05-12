# lookagain

Sequential code review with fresh agent contexts. Each pass runs in an independent subagent, ensuring unbiased analysis that catches issues other passes might miss.

## Why?

A single code review pass catches ~60-70% of issues. Running multiple independent passes with fresh contexts significantly increases coverage. This plugin automates that workflow.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   /look:again                       │
│                                                     │
│   ┌────────────────────────────────────────────┐    │
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
│   └────────────────────────────────────────────┘    │
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

## Updating

To update to the latest version:

```bash
/plugin marketplace update hartbrook-plugins
/plugin uninstall look@hartbrook-plugins
/plugin install look@hartbrook-plugins
```

## Development

```bash
make test          # Structural validation (offline, fast)
make eval          # Behavioral evals via promptfoo (requires ANTHROPIC_API_KEY)
make integration   # End-to-end integration test (requires ANTHROPIC_API_KEY)
make dev           # Build and start Claude Code with the plugin loaded
```

Run `make test` before every commit (free, offline). Run `make eval` after changing prompt wording or argument handling. Run `make integration` after changes to the review pipeline or output format. See [CONTRIBUTING.md](CONTRIBUTING.md) for details on what each layer catches.

## Why Multiple Passes Work

A natural question: why does a fresh pass find issues the previous one missed? It's not a single cause — several factors compound.

**Stochastic sampling.** LLMs are probabilistic. Each run samples a different path through the reasoning space. One pass might focus on error handling, another on boundary conditions, another on security. The model *can* find any given issue, but on any single run the sampling path may not lead there. Multiple independent runs cover more of the distribution.

**Context anchoring.** Once a reviewer commits to a line of analysis early in a pass, that reasoning occupies context and steers what it looks for next. If pass 1 spends its early tokens analyzing a race condition, it's primed to find more concurrency issues — not the SQL injection two files over. A fresh context has no such anchoring, so it approaches the code from a different angle.

**Bugs mask bugs.** When auto-fix resolves a `must_fix` issue between passes, the next reviewer sees different code. A null dereference on line 12 can prevent the reviewer from reasoning clearly about the logic on lines 15–30 that depends on the same variable. Fix line 12, and the downstream issue becomes visible.

**Finite output budget.** Each reviewer agent has a limited token budget for its response. A thorough review of a large diff can't enumerate every issue in one pass — it has to prioritize. Different passes prioritize differently due to sampling, so the union of findings is larger than any single pass.

The key design decision is **independence**. If you asked the same agent to "look again" within the same context, it would anchor on its prior findings and mostly confirm them. Spawning a fresh subagent with no knowledge of earlier passes avoids this confirmation bias.

## License

MIT
