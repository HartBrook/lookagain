#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 is required but not found"
    exit 1
fi

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

check_file() {
    if [[ -f "$PROJECT_ROOT/$1" ]]; then
        pass "$1 exists"
    else
        fail "$1 missing"
    fi
}

check_json_field() {
    local file="$1" field="$2"
    if python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if sys.argv[2] in d else 1)" "$file" "$field" 2>/dev/null; then
        pass "$field present"
    else
        fail "$field missing from $(basename "$file")"
    fi
}

check_frontmatter() {
    local file="$1"
    shift
    local required_fields=("$@")
    local relpath="${file#"$PROJECT_ROOT"/}"

    # Check file starts with ---
    if ! head -1 "$file" | grep -q "^---$"; then
        fail "$relpath: no frontmatter delimiter"
        return
    fi

    # Check required fields in frontmatter via grep (robust against lenient YAML)
    local frontmatter
    frontmatter=$(awk 'NR==1{next} /^---$/{exit} {print}' "$file")
    local missing=0
    for field in "${required_fields[@]}"; do
        if ! echo "$frontmatter" | grep -q "^${field}:"; then
            fail "$relpath: field '$field' not found"
            missing=1
        fi
    done
    if [[ $missing -eq 0 ]]; then
        pass "$relpath frontmatter valid"
    fi
}

# ============================================================
# Test Groups
# ============================================================

test_plugin_json() {
    local pjson="$PROJECT_ROOT/src/dot-claude-plugin/plugin.json"

    # Valid JSON
    if python3 -c "import json; json.load(open('$pjson'))" 2>/dev/null; then
        pass "plugin.json is valid JSON"
    else
        fail "plugin.json is not valid JSON"
        return
    fi

    # Required fields
    for field in name version description author commands agents; do
        check_json_field "$pjson" "$field"
    done

    # Version matches semver
    if python3 -c "
import json, re, sys
v = json.load(open('$pjson'))['version']
sys.exit(0 if re.match(r'^\d+\.\d+\.\d+$', v) else 1)
" 2>/dev/null; then
        pass "version is valid semver"
    else
        fail "version is not valid semver"
    fi

    # Author has name
    if python3 -c "
import json, sys
d = json.load(open('$pjson'))
sys.exit(0 if isinstance(d.get('author'), dict) and 'name' in d['author'] else 1)
" 2>/dev/null; then
        pass "author.name present"
    else
        fail "author must be an object with name field"
    fi
}

test_required_files() {
    check_file "src/dot-claude-plugin/plugin.json"
    check_file "src/commands/again.md"
    check_file "src/agents/lookagain-reviewer.md"
    check_file "src/skills/lookagain-output-format/SKILL.md"
    check_file "src/dot-claude/settings.local.json"
    check_file "README.md"
    check_file "LICENSE"
    check_file "CHANGELOG.md"
}

test_frontmatter() {
    check_frontmatter "$PROJECT_ROOT/src/commands/again.md" name description
    check_frontmatter "$PROJECT_ROOT/src/agents/lookagain-reviewer.md" name description tools
    check_frontmatter "$PROJECT_ROOT/src/skills/lookagain-output-format/SKILL.md" name description
}

test_cross_references() {
    local pjson="$PROJECT_ROOT/src/dot-claude-plugin/plugin.json"

    # Commands resolve
    while IFS= read -r cmd; do
        local resolved="$PROJECT_ROOT/src/${cmd#./}"
        if [[ -f "$resolved" ]]; then
            pass "command $cmd resolves"
        else
            fail "command $cmd not found at src/${cmd#./}"
        fi
    done < <(python3 -c "import json; [print(c) for c in json.load(open('$pjson')).get('commands', [])]")

    # Agents resolve
    while IFS= read -r agent; do
        local resolved="$PROJECT_ROOT/src/${agent#./}"
        if [[ -f "$resolved" ]]; then
            pass "agent $agent resolves"
        else
            fail "agent $agent not found at src/${agent#./}"
        fi
    done < <(python3 -c "import json; [print(a) for a in json.load(open('$pjson')).get('agents', [])]")

    # Skills resolve with SKILL.md
    while IFS= read -r skill; do
        local resolved="$PROJECT_ROOT/src/${skill#./}"
        if [[ -d "$resolved" ]] && [[ -f "$resolved/SKILL.md" ]]; then
            pass "skill $skill resolves with SKILL.md"
        else
            fail "skill $skill not found or missing SKILL.md"
        fi
    done < <(python3 -c "import json; [print(s) for s in json.load(open('$pjson')).get('skills', [])]")
}

test_build() {
    # Clean and build
    rm -rf "$PROJECT_ROOT/dist"
    "$PROJECT_ROOT/scripts/package.sh" > /dev/null

    local dist="$PROJECT_ROOT/dist/lookagain"

    # Check structure
    if [[ -d "$dist/.claude" ]]; then
        pass "dist/.claude/ created"
    else
        fail "dist/.claude/ missing"
    fi

    if [[ -d "$dist/.claude-plugin" ]]; then
        pass "dist/.claude-plugin/ created"
    else
        fail "dist/.claude-plugin/ missing"
    fi

    if python3 -c "import json; json.load(open('$dist/.claude-plugin/plugin.json'))" 2>/dev/null; then
        pass "dist plugin.json is valid JSON"
    else
        fail "dist plugin.json is invalid"
    fi

    for f in commands/again.md agents/lookagain-reviewer.md skills/lookagain-output-format/SKILL.md README.md; do
        if [[ -f "$dist/$f" ]]; then
            pass "dist/$f exists"
        else
            fail "dist/$f missing"
        fi
    done

    # Zip exists with correct version
    local version
    version=$(python3 -c "import json; print(json.load(open('$PROJECT_ROOT/src/dot-claude-plugin/plugin.json'))['version'])")
    if [[ -f "$PROJECT_ROOT/dist/lookagain-v${version}.zip" ]]; then
        pass "zip archive lookagain-v${version}.zip exists"
    else
        fail "zip archive not found"
    fi
}

test_settings() {
    local settings="$PROJECT_ROOT/src/dot-claude/settings.local.json"

    if python3 -c "import json; json.load(open('$settings'))" 2>/dev/null; then
        pass "settings.local.json is valid JSON"
    else
        fail "settings.local.json is not valid JSON"
        return
    fi

    if python3 -c "
import json, sys
d = json.load(open('$settings'))
sys.exit(0 if isinstance(d.get('permissions', {}).get('allow'), list) else 1)
" 2>/dev/null; then
        pass "permissions.allow is an array"
    else
        fail "permissions.allow missing or not an array"
    fi
}

# ============================================================
# Run
# ============================================================

echo "=== lookagain test suite ==="
echo ""

echo "--- plugin.json ---"
test_plugin_json
echo ""

echo "--- required files ---"
test_required_files
echo ""

echo "--- frontmatter ---"
test_frontmatter
echo ""

echo "--- cross-references ---"
test_cross_references
echo ""

echo "--- settings ---"
test_settings
echo ""

echo "--- build ---"
test_build
echo ""

echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
