---
name: again
description: Run sequential code review passes with fresh contexts to catch more issues
arguments:
  - name: passes
    description: Number of review passes to run
    default: "3"
  - name: target
    description: Target directory or files to review (default: current directory)
    default: "."
  - name: auto-fix
    description: Automatically fix must_fix issues between passes (true/false)
    default: "true"
  - name: max-passes
    description: Maximum passes if must_fix issues persist
    default: "7"
---

# Iterative Code Review

You are orchestrating a sequential, multi-pass code review. Passes run ONE AT A TIME, with fixes applied between each pass so the next reviewer sees the improved code.

## Configuration from arguments

- **Passes**: $ARGUMENTS.passes
- **Target**: $ARGUMENTS.target
- **Auto-fix**: $ARGUMENTS.auto-fix
- **Max passes**: $ARGUMENTS.max-passes

## Process

### Phase 0: Setup

1. Clean previous results: `rm -rf .lookagain && mkdir -p .lookagain`
2. Do NOT explore or read the codebase yourself. You are an orchestrator — your only job is to spawn reviewers, collect results, apply fixes, and aggregate. The reviewers will read the code.

### Phase 1: Execute Review Passes Sequentially

CRITICAL: Passes MUST run in sequence, NOT in parallel. Each pass reviews the code AS IT EXISTS AFTER previous fixes.

Repeat the following loop for each pass (1 through configured number of passes):

**Step 1 — Review**: Spawn a fresh subagent using the Task tool with the `lookagain-reviewer` agent.
- Include in the prompt: pass number, target path, and instruction to output JSON.
- Do NOT include findings from previous passes. The subagent must review independently.
- WAIT for the subagent to complete before proceeding.

**Step 2 — Collect**: Parse the JSON findings from the subagent response.
- Expected structure: `{ "issues": [{ "severity": "must_fix|should_fix|suggestion", "title": "...", "description": "...", "file": "...", "line": N, "suggested_fix": "..." }] }`
- Store findings and track which pass found each issue.

**Step 3 — Fix**: If auto-fix is enabled, apply fixes for `must_fix` issues NOW, before the next pass.
- Make minimal code changes. Do not refactor.
- Do NOT fix `should_fix` or `suggestion` items.
- The next pass will review the code WITH these fixes applied.

**Step 4 — Log and continue**: Log "Pass N complete. Found X must_fix, Y should_fix, Z suggestions." then proceed to the next pass.

After the configured passes, if `must_fix` issues remain and we haven't hit max-passes, run additional passes.

### Phase 2: Aggregate Results

After all passes complete:

1. **Deduplicate findings**
   - Same issue found in multiple passes = higher confidence
   - Key on (file, title) - issues with same file and title are duplicates
   - Track which passes found each unique issue

2. **Calculate confidence scores**
   - Confidence = (passes that found this issue) / (total passes) * 100%

3. **Generate summary report**
   - Group by severity
   - Sort by confidence within each group
   - Include file locations and suggested fixes

### Phase 3: Save Results

Save results to `.lookagain/` using the Write tool:

1. `pass-N.json` - Raw findings from each pass (save after each pass completes)
2. `aggregate.json` - Machine-readable findings
3. `aggregate.md` - Human-readable report

### Output Format

Present the final summary to the user:

```
## Iterative Review Complete

**Passes completed**: N
**Unique issues found**: X

### Must Fix (N issues)

| Issue | File | Confidence | Fixed |
| ----- | ---- | ---------- | ----- |
| ...   | ...  | ...%       | ✓/✗   |

### Should Fix (N issues)

| Issue | File | Confidence |
| ----- | ---- | ---------- |
| ...   | ...  | ...%       |

### Suggestions (N issues)

| Issue | File | Confidence |
| ----- | ---- | ---------- |
| ...   | ...  | ...%       |

Full report saved to `.lookagain/aggregate.md`
```

## Important Rules

1. **Sequential, not parallel**: NEVER launch multiple review passes at the same time. Each pass must complete and its fixes must be applied before starting the next pass.

2. **Fresh context per pass**: Always use Task tool for subagents. Never try to "reset" context manually.

3. **Subagent independence**: Do NOT tell subagents what previous passes found. The value is independent analysis on the current state of the code.

4. **Minimal fixes**: When auto-fixing, change only what's necessary. Don't refactor.

5. **Structured output**: Ensure subagent returns valid JSON. If parsing fails, log error and continue.

6. **Respect max-passes**: Never exceed max-passes, even if must_fix issues remain.
