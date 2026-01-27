#!/usr/bin/env bash
set -euo pipefail

# Package lookagain plugin for distribution
# Renames dot-* directories to .* and creates distributable zip

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_ROOT/dist"

# Get version from plugin.json
VERSION=$(grep -o '"version": *"[^"]*"' "$PROJECT_ROOT/src/dot-claude-plugin/plugin.json" | cut -d'"' -f4)

if [[ -z "$VERSION" ]]; then
    echo "Error: Could not extract version from plugin.json"
    exit 1
fi

echo "Packaging lookagain v$VERSION..."

# Clean previous build
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR/lookagain"

# Copy and rename directories
cp -r "$PROJECT_ROOT/src/dot-claude" "$DIST_DIR/lookagain/.claude"
cp -r "$PROJECT_ROOT/src/dot-claude-plugin" "$DIST_DIR/lookagain/.claude-plugin"
cp -r "$PROJECT_ROOT/src/commands" "$DIST_DIR/lookagain/commands"
cp -r "$PROJECT_ROOT/src/agents" "$DIST_DIR/lookagain/agents"
cp -r "$PROJECT_ROOT/src/skills" "$DIST_DIR/lookagain/skills"

# Copy root files
cp "$PROJECT_ROOT/README.md" "$DIST_DIR/lookagain/"
cp "$PROJECT_ROOT/LICENSE" "$DIST_DIR/lookagain/"
cp "$PROJECT_ROOT/CHANGELOG.md" "$DIST_DIR/lookagain/"

# Create zip archive
cd "$DIST_DIR"
zip -r "lookagain-v$VERSION.zip" lookagain

echo ""
echo "Build complete:"
echo "  dist/lookagain/          - Unpacked plugin"
echo "  dist/lookagain-v$VERSION.zip - Distribution archive"
