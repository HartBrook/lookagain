---
name: tidy
description: Remove old lookagain review runs, keeping today's results by default
tools: Glob, Bash(rm -rf .lookagain/????-??-??T??-??-??)
argument-hint: "[key=value ...]"
---

# Tidy Old Review Runs

You are cleaning up old review results from `.lookagain/`.

## Parse arguments

The user may pass key=value pairs after the command name. The raw argument string is:

$ARGUMENTS

Parse the following settings from the argument string. For any key not provided, use the default.

| Key | Default | Description |
|---|---|---|
| `keep` | `1` | Keep runs from the last N days |
| `all` | `false` | Remove all runs including today's (`true` or `false`) |

## Process

1. Use Glob to list all directories under `.lookagain/` matching the pattern `.lookagain/????-??-??T??-??-??/`.

2. If no run directories exist, tell the user there's nothing to tidy and stop.

3. Determine which runs to remove:
   - If the resolved `all` value is `true`, remove ALL run directories.
   - Otherwise, calculate the cutoff date by subtracting the resolved `keep` value (in days) from today's date. Remove only run directories whose date portion (the `YYYY-MM-DD` prefix of the directory name) is strictly before the cutoff date.

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

All N run(s) are within the keep window.
```
