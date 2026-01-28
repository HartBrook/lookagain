# Contributing to lookagain

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/HartBrook/lookagain.git
   cd lookagain
   ```

2. Ensure you have [Claude Code](https://claude.ai/code) installed.

## Project Structure

```
lookagain/
├── src/
│   ├── commands/           # Plugin commands
│   │   └── again.md        # Main orchestrator
│   ├── agents/             # Subagent definitions
│   │   └── lookagain-reviewer.md
│   ├── skills/             # Output format specs
│   │   └── lookagain-output-format/
│   ├── dot-claude-plugin/  # Plugin manifest (becomes .claude-plugin/)
│   └── dot-claude/         # Claude settings (becomes .claude/)
├── scripts/
│   ├── package.sh          # Build script
│   └── test.sh             # Plugin validation tests
├── dist/                   # Build output (git-ignored)
└── Makefile
```

## Development Workflow

### Build and Test Locally

```bash
# Build and start Claude Code with the plugin loaded
make dev

# Or just build without starting
make build

# Clean build artifacts
make clean

# Show all available commands
make help
```

`make dev` builds the plugin and starts a new Claude Code session with it loaded. Test with `/look:again`.

### Making Changes

1. Edit files in `src/`
2. Run `make dev` to rebuild and start Claude Code with the plugin
3. Test with `/look:again`
4. Exit and repeat

### Key Files

- **[src/commands/again.md](src/commands/again.md)**: Main orchestrator logic. Controls pass execution, auto-fixing, and aggregation.
- **[src/agents/lookagain-reviewer.md](src/agents/lookagain-reviewer.md)**: Reviewer subagent. Defines how individual review passes work.
- **[src/skills/lookagain-output-format/SKILL.md](src/skills/lookagain-output-format/SKILL.md)**: JSON output format specification.
- **[src/dot-claude-plugin/plugin.json](src/dot-claude-plugin/plugin.json)**: Plugin metadata and version.

## Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Test locally with `make dev`
5. Commit with a clear message
6. Open a pull request

## Versioning

Update the version in `src/dot-claude-plugin/plugin.json` when making releases.
