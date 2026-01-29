#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# ============================================================
# Integration test for look:again
#
# Creates a temp git repo with a contrived buggy file, runs
# the plugin with 2 passes (expecting pass 1 fixes the bugs
# and pass 2 finds no must_fix issues), then chains a tidy
# to verify cleanup works.
#
# Requires: ANTHROPIC_API_KEY, claude CLI
#
# Uses --dangerously-skip-permissions since this runs in an
# isolated temp directory. Times out after 5 minutes per
# claude invocation.
# ============================================================

TIMEOUT=300

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
    echo "Error: ANTHROPIC_API_KEY is required"
    exit 1
fi

if ! command -v claude >/dev/null 2>&1; then
    echo "Error: claude CLI is required but not found"
    exit 1
fi

# Build the plugin
echo "Building plugin..."
"$PROJECT_ROOT/scripts/package.sh" > /dev/null

WORK_DIR=$(mktemp -d)
cleanup() {
    if [[ "${TEST_FAILED:-0}" -eq 1 ]]; then
        echo ""
        echo "Preserving work directory for debugging: $WORK_DIR"
    else
        rm -rf "$WORK_DIR"
    fi
}
trap cleanup EXIT

echo "Work directory: $WORK_DIR"

# Helper: run claude with a timeout (perl, since macOS lacks GNU timeout)
run_claude() {
    local output_file="$1"
    shift
    perl -e '
        alarm shift;
        $SIG{ALRM} = sub { kill "TERM", $pid; exit 124 };
        $pid = fork // die;
        unless ($pid) { exec @ARGV; die "exec failed: $!" }
        waitpid $pid, 0;
        exit ($? >> 8);
    ' "$TIMEOUT" \
        claude -p "$@" \
        --plugin-dir "$PROJECT_ROOT/dist/lookagain" \
        --dangerously-skip-permissions \
        > "$output_file" 2>&1
    local exit_code=$?

    if [[ $exit_code -eq 124 ]]; then
        echo "Error: claude timed out after ${TIMEOUT}s"
    elif [[ $exit_code -ne 0 ]]; then
        echo "Warning: claude exited with code $exit_code (continuing to check output)"
    fi
    return 0
}

# ============================================================
# Setup: create a git repo with a buggy file
# ============================================================

cd "$WORK_DIR"
git init -q
git config user.email "test@test.com"
git config user.name "Test"

# Create a Python file with obvious logic bugs:
# 1. Variable is overwritten before use (result always 0.0)
# 2. Accessing attribute on None without null check
cat > buggy.py << 'PYEOF'
def calculate_total(items: list[dict]) -> float:
    """Calculate the total price of all items."""
    total = 0.0
    for item in items:
        total += item["price"] * item["quantity"]
    total = 0.0
    return total


def find_user_name(users: list[dict], user_id: str) -> str:
    """Find a user's name by ID."""
    result = None
    for user in users:
        if user["id"] == user_id:
            result = user
    return result["name"]
PYEOF

ORIGINAL_CONTENT=$(cat buggy.py)

git add buggy.py
git commit -q -m "Add buggy module"

# ============================================================
# Phase 1: run look:again (2 passes, fast model, auto-fix on)
# ============================================================

echo ""
echo "Phase 1: Running look:again against buggy.py (2 passes, fast model, auto-fix on)..."
echo ""

run_claude "$WORK_DIR/again_output.txt" \
    "/look:again target=buggy.py passes=2 auto-fix=true model=fast"

echo "look:again output saved to $WORK_DIR/again_output.txt"

# ============================================================
# Verify look:again results
#
# Disable set -e so all checks run even if commands fail.
# ============================================================

set +e

PASS=0
FAIL=0

pass() {
    PASS=$((PASS + 1))
    echo "  ✓ $1"
}

fail() {
    FAIL=$((FAIL + 1))
    echo "  ✗ $1"
}

echo ""
echo "=== look:again checks ==="
echo ""

# 1. File was modified (auto-fix applied)
CURRENT_CONTENT=$(cat buggy.py)
if [[ "$CURRENT_CONTENT" != "$ORIGINAL_CONTENT" ]]; then
    pass "buggy.py was modified (auto-fix applied)"
else
    fail "buggy.py was NOT modified (auto-fix did not apply)"
fi

# 2. The double-assignment bug is fixed
if ! grep -q 'total = 0\.0' buggy.py || [[ $(grep -c 'total = 0\.0' buggy.py) -lt 2 ]]; then
    pass "double-assignment bug appears fixed (total = 0.0 not duplicated)"
else
    fail "double-assignment bug still present"
fi

# 3. Output directory exists
if [[ -d ".lookagain" ]]; then
    pass ".lookagain/ directory created"
else
    fail ".lookagain/ directory not created"
fi

# 4. Run directory matches expected pattern
RUN_DIR=""
if [[ -d ".lookagain" ]]; then
    RUN_DIRS=$(find .lookagain -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)
    RUN_COUNT=$(echo "$RUN_DIRS" | grep -c . 2>/dev/null || echo 0)
    if [[ "$RUN_COUNT" -ge 1 ]]; then
        pass "found $RUN_COUNT run directory(ies)"
        RUN_DIR=$(echo "$RUN_DIRS" | head -1)
    else
        fail "no run directories found"
    fi
else
    fail "no run directories found (no .lookagain/)"
fi

# 5. Both pass output files exist and are valid JSON
for pass_num in 1 2; do
    if [[ -n "$RUN_DIR" ]] && [[ -f "$RUN_DIR/pass-${pass_num}.json" ]]; then
        if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$RUN_DIR/pass-${pass_num}.json" 2>/dev/null; then
            pass "pass-${pass_num}.json exists and is valid JSON"
        else
            fail "pass-${pass_num}.json exists but is not valid JSON"
        fi
    else
        fail "pass-${pass_num}.json not found"
    fi
done

# 6. Pass 1 found must_fix issues (the contrived bugs)
if [[ -n "$RUN_DIR" ]] && [[ -f "$RUN_DIR/pass-1.json" ]]; then
    if python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
issues = d.get('issues', [])
must_fix = [i for i in issues if i.get('severity') == 'must_fix']
sys.exit(0 if must_fix else 1)
" "$RUN_DIR/pass-1.json" 2>/dev/null; then
        pass "pass 1 found must_fix issues"
    else
        fail "pass 1 did not find must_fix issues"
    fi
else
    fail "cannot check pass 1 must_fix issues (file missing)"
fi

# 7. Pass 2 found no must_fix issues (bugs were fixed after pass 1)
if [[ -n "$RUN_DIR" ]] && [[ -f "$RUN_DIR/pass-2.json" ]]; then
    if python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
issues = d.get('issues', [])
must_fix = [i for i in issues if i.get('severity') == 'must_fix']
sys.exit(0 if not must_fix else 1)
" "$RUN_DIR/pass-2.json" 2>/dev/null; then
        pass "pass 2 found no must_fix issues (bugs were fixed)"
    else
        fail "pass 2 still found must_fix issues after auto-fix"
    fi
else
    fail "cannot check pass 2 must_fix issues (file missing)"
fi

# 8. Aggregate JSON exists with issues array
if [[ -n "$RUN_DIR" ]] && [[ -f "$RUN_DIR/aggregate.json" ]]; then
    if python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
assert isinstance(d.get('issues', d.get('findings', [])), list), 'no issues array'
" "$RUN_DIR/aggregate.json" 2>/dev/null; then
        pass "aggregate.json exists with issues array"
    else
        fail "aggregate.json missing issues array"
    fi
else
    fail "aggregate.json not found"
fi

# 9. Aggregate markdown exists and is non-empty
if [[ -n "$RUN_DIR" ]] && [[ -f "$RUN_DIR/aggregate.md" ]]; then
    if [[ -s "$RUN_DIR/aggregate.md" ]]; then
        pass "aggregate.md exists and is non-empty"
    else
        fail "aggregate.md exists but is empty"
    fi
else
    fail "aggregate.md not found"
fi

# ============================================================
# Phase 2: run look:tidy to clean up the run
# ============================================================

set -e

echo ""
echo "Phase 2: Running look:tidy all=true..."
echo ""

run_claude "$WORK_DIR/tidy_output.txt" \
    "/look:tidy all=true"

echo "look:tidy output saved to $WORK_DIR/tidy_output.txt"

set +e

echo ""
echo "=== look:tidy checks ==="
echo ""

# 10. Run directory was removed by tidy
if [[ -n "$RUN_DIR" ]] && [[ ! -d "$RUN_DIR" ]]; then
    pass "run directory removed by tidy"
elif [[ -n "$RUN_DIR" ]]; then
    fail "run directory still exists after tidy"
else
    fail "cannot check tidy (no run directory to remove)"
fi

# 11. .lookagain/ is empty or gone
if [[ ! -d ".lookagain" ]]; then
    pass ".lookagain/ removed entirely"
else
    REMAINING=$(find .lookagain -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$REMAINING" -eq 0 ]]; then
        pass ".lookagain/ exists but is empty (all runs removed)"
    else
        fail ".lookagain/ still has $REMAINING run directories after tidy all=true"
    fi
fi

# ============================================================
# Summary
# ============================================================

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ $FAIL -gt 0 ]]; then
    TEST_FAILED=1
    echo ""
    echo "--- look:again output (first 200 lines) ---"
    head -200 "$WORK_DIR/again_output.txt"
    echo "--- end again output ---"
    echo ""
    echo "--- look:tidy output (first 100 lines) ---"
    head -100 "$WORK_DIR/tidy_output.txt" 2>/dev/null || echo "(no tidy output)"
    echo "--- end tidy output ---"
    exit 1
fi
