---
name: lookagain
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

You are orchestrating a multi-pass code review. Each pass MUST use a fresh subagent via the Task tool to ensure independent analysis.

## Configuration from arguments

- **Passes**: $ARGUMENTS.passes
- **Target**: $ARGUMENTS.target
- **Auto-fix**: $ARGUMENTS.auto-fix
- **Max passes**: $ARGUMENTS.max-passes

## Process

### Phase 1: Execute Review Passes

For each pass from 1 to the configured number of passes:

1. **Spawn a fresh subagent** using the Task tool with the `lookagain-reviewer` agent
   - The subagent prompt should include: pass number, target path, and instruction to output JSON
   - CRITICAL: Each Task invocation creates a fresh context. Do not pass previous findings to the subagent.

2. **Collect the subagent's response**
   - Parse the JSON findings from the subagent
   - Findings should have structure: `{ "issues": [{ "severity": "must_fix|should_fix|suggestion", "title": "...", "description": "...", "file": "...", "line": N, "suggested_fix": "..." }] }`

3. **Store findings for this pass**
   - Keep track of which pass found each issue

4. **Apply fixes if auto-fix is enabled**
   - For each `must_fix` issue, make the minimal code change to fix it
   - Do NOT fix `should_fix` or `suggestion` items automatically

5. **Check continuation condition**
   - If this was the last configured pass AND there are still `must_fix` issues AND we haven't hit max-passes, continue with another pass
   - Log: "Pass N complete. Found X must_fix, Y should_fix, Z suggestions."

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

Create `.lookagain/` directory with:

1. `aggregate.md` - Human-readable report
2. `aggregate.json` - Machine-readable findings
3. `pass-N.json` - Raw findings from each pass (for debugging)

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

1. **Fresh context per pass**: Always use Task tool for subagents. Never try to "reset" context manually.

2. **Subagent independence**: Do NOT tell subagents what previous passes found. The value is independent analysis.

3. **Minimal fixes**: When auto-fixing, change only what's necessary. Don't refactor.

4. **Structured output**: Ensure subagent returns valid JSON. If parsing fails, log error and continue.

5. **Respect max-passes**: Never exceed max-passes, even if must_fix issues remain.
