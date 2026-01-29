---
name: again
description: Run sequential code review passes with fresh contexts to catch more issues
argument-hint: "[key=value ...]"
---

# Iterative Code Review

You orchestrate sequential, multi-pass code review. Passes run one at a time with fixes applied between each so the next reviewer sees improved code.

## Phase 0: Setup

### Parse arguments

The user may pass key=value pairs after the command name. The raw argument string is:

$ARGUMENTS

Parse the following settings from the argument string. For any key not provided, use the default.

| Key | Default | Description |
|---|---|---|
| `passes` | `3` | Number of review passes to run |
| `target` | `staged` | What to review: `staged`, `commit`, `branch`, or a file/directory path |
| `auto-fix` | `true` | Automatically fix must_fix issues between passes (`true` or `false`) |
| `model` | `thorough` | Reviewer model: `fast` (haiku), `balanced` (sonnet), `thorough` (inherit) |
| `max-passes` | `7` | Maximum passes if must_fix issues persist |

**Log the resolved configuration** so it is visible in the output:

```
Configuration:
  passes:     <resolved value>
  target:     <resolved value>
  auto-fix:   <resolved value>
  model:      <resolved value>
  max-passes: <resolved value>
```

### Generate run ID

Generate a run ID: `YYYY-MM-DDTHH-MM-SS`. All output goes under `.lookagain/<run-id>/`.

### Orchestrator role

Do NOT read the codebase yourself. You are the orchestrator — spawn reviewers, collect results, apply fixes, aggregate. Create a TodoWrite list with one item per pass plus aggregation. Mark items `in_progress` when starting and `completed` when done.

### Resolve scope

Using the resolved `target` value, determine the scope instruction to pass to each reviewer:

| Target value | Scope instruction for reviewer |
|---|---|
| `staged` | "scope: staged — review only staged changes" |
| `commit` | "scope: commit — review the last commit" |
| `branch` | "scope: branch — review all changes on this branch vs base" |
| Any path | "scope: path — review files in `<target>`" |

### Resolve model

Using the resolved `model` value, map to the Task tool model parameter:

| Model value | Task model |
|---|---|
| `fast` | `haiku` |
| `balanced` | `sonnet` |
| `thorough` | (omit — inherits current model) |

## Phase 1: Sequential Review Passes

CRITICAL: Passes run in sequence, NOT in parallel. Each pass reviews code after previous fixes.

For each pass (1 through the resolved `passes` value):

**Review**: Spawn a fresh subagent via the Task tool using the `lookagain-reviewer` agent. Include: pass number, scope instruction, and instruction to use the `lookagain-output-format` skill. Set the model parameter based on the resolved model. Do NOT include findings from previous passes.

**Collect**: Parse the JSON response. Store findings and track which pass found each issue.

**Fix**: If the resolved `auto-fix` value is `true`, apply fixes for `must_fix` issues only. Minimal changes, no refactoring. If `auto-fix` is `false`, skip this step entirely — do not apply any fixes.

**Log**: "Pass N complete. Found X must_fix, Y should_fix, Z suggestions."

After completing the configured number of passes, if `must_fix` issues remain and total passes < the resolved `max-passes` value, run additional passes.

## Phase 2: Aggregate

1. **Deduplicate** on (file, title). Same issue across passes = higher confidence.
2. **Score**: Confidence = (passes finding issue) / (total passes) x 100%.
3. **Group** by severity, sort by confidence within groups.

## Phase 3: Save and Report

Save to `.lookagain/<run-id>/`:
- `pass-N.json` after each pass
- `aggregate.json` and `aggregate.md` after aggregation

Present the final summary to the user in this format:

```
## Iterative Review Complete

**Passes completed**: N
**Unique issues found**: X

### Must Fix (N issues)

| Issue | File | Confidence | Fixed |
| ----- | ---- | ---------- | ----- |
| ...   | ...  | ...%       | Yes/No |

### Should Fix (N issues)

| Issue | File | Confidence |
| ----- | ---- | ---------- |
| ...   | ...  | ...%       |

### Suggestions (N issues)

| Issue | File | Confidence |
| ----- | ---- | ---------- |
| ...   | ...  | ...%       |

Full report saved to `.lookagain/<run-id>/aggregate.md`
```

Include the count of previous runs (glob `.lookagain/????-??-??T??-??-??/`, subtract 1). Mention `/look:tidy` if previous runs exist.

## Rules

1. **Sequential**: Never launch passes in parallel. Each must complete before the next starts.
2. **Fresh context**: Always use the Task tool for subagents.
3. **Independence**: Never tell subagents what previous passes found.
4. **Minimal fixes**: Only apply fixes when the resolved `auto-fix` value is `true`.
5. **Valid JSON**: If subagent output fails to parse, log the error and continue.
6. **Respect max-passes**: Never exceed the resolved `max-passes` value.
