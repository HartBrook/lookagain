---
name: tidy
description: Remove old lookagain review runs, keeping today's results by default
tools: Glob, Bash(rm -rf .lookagain/????-??-??T??-??-??)
arguments:
  - name: keep
    description: "Keep runs from the last N days (default: 1)"
    default: "1"
  - name: all
    description: "Remove all runs including today's (true/false)"
    default: "false"
---

# Tidy Old Review Runs

You are cleaning up old review results from `.lookagain/`.

## Process

1. Use Glob to list all directories under `.lookagain/` matching the pattern `.lookagain/????-??-??T??-??-??/`.

2. If no run directories exist, tell the user there's nothing to tidy and stop.

3. Determine which runs to remove:
   - If `$ARGUMENTS.all` is `true`, remove ALL run directories.
   - Otherwise, calculate the cutoff date by subtracting `$ARGUMENTS.keep` days from today's date. Remove only run directories whose date portion (the `YYYY-MM-DD` prefix of the directory name) is strictly before the cutoff date.

4. Before deleting, validate each directory name matches the exact pattern `YYYY-MM-DDTHH-MM-SS` (all digits in the right positions). Skip any directory that doesn't match.

5. For each validated run directory to remove, use Bash to delete it: `rm -rf .lookagain/<run-id>`

6. Report what was done:

```
## Tidy Complete

Removed N run(s): <list of run-ids removed>
Kept M run(s): <list of run-ids kept>
```

If nothing was removed, say so:

```
## Nothing to Tidy

All N run(s) are within the last $ARGUMENTS.keep day(s).
```
