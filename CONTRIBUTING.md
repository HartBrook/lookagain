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
├── .claude-plugin/
│   └── marketplace.json    # Marketplace manifest
├── src/
│   ├── commands/           # Plugin commands
│   │   ├── again.md        # Main orchestrator
│   │   └── tidy.md         # Tidy old review runs
│   ├── agents/             # Subagent definitions
│   │   └── lookagain-reviewer.md
│   ├── skills/             # Output format specs
│   │   └── lookagain-output-format/
│   ├── dot-claude-plugin/  # Plugin manifest (becomes .claude-plugin/)
│   └── dot-claude/         # Claude settings (becomes .claude/)
├── scripts/
│   ├── package.sh          # Build script
│   └── test.sh             # Plugin validation tests
├── evals/                  # Behavioral evals (promptfoo)
│   ├── promptfooconfig.yaml
│   └── prompt-loader.js
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

### Running Tests

```bash
# Structural validation (file existence, JSON, frontmatter, cross-refs)
make test

# Behavioral evals — verifies models interpret prompt arguments correctly
# Requires ANTHROPIC_API_KEY
make eval
```

`make test` runs fast, offline checks that validate plugin structure: file existence, JSON validity, frontmatter fields, cross-references between manifests, and that all frontmatter arguments are referenced as `$ARGUMENTS.<name>` in the instruction body (not just in display sections).

`make eval` runs [promptfoo](https://promptfoo.dev) evals that send the interpolated prompts to Claude and assert on behavioral correctness. For example, it verifies that `auto-fix=false` causes the model to skip fixes, and that `passes=5` results in 5 planned passes.

Evals require an Anthropic API key and cost a small amount per run. Set the key before running:

```bash
# Option 1: export for the current shell session
export ANTHROPIC_API_KEY=sk-ant-...

# Option 2: inline for a single run
ANTHROPIC_API_KEY=sk-ant-... make eval
```

Get an API key at [console.anthropic.com](https://console.anthropic.com/settings/keys).

### Testing via Marketplace (local)

You can also test the plugin through the marketplace install flow, which is closer to what end users experience:

```bash
# First time: add the local marketplace
/plugin marketplace add ./

# Install the plugin
/plugin install look@hartbrook-plugins

# After making changes, reinstall to pick them up
/plugin uninstall look@hartbrook-plugins
/plugin marketplace update hartbrook-plugins
/plugin install look@hartbrook-plugins
```

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
- **[src/commands/tidy.md](src/commands/tidy.md)**: Tidy command for pruning old review runs.
- **[.claude-plugin/marketplace.json](.claude-plugin/marketplace.json)**: Marketplace manifest for plugin discovery and installation.

### Writing Command Prompts

When editing or adding command prompts in `src/commands/`:

- Define arguments in the YAML frontmatter with `name`, `description`, and `default`.
- Reference arguments in the instruction body using `$ARGUMENTS.<name>` — not just in display sections. The executing agent needs to see the interpolated value at the point where it makes decisions. For example, write `If $ARGUMENTS.auto-fix is true` rather than `If auto-fix is enabled`.
- `make test` enforces that every frontmatter argument appears as `$ARGUMENTS.<name>` somewhere in the body. If you add an argument, the test will fail until you reference it.
- After changing prompt logic, run `make eval` to verify models still interpret the arguments correctly.

## Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Test locally with `make dev`
5. Commit with a clear message
6. Open a pull request

## Versioning

Update the version in `src/dot-claude-plugin/plugin.json` when making releases. The marketplace entry in `.claude-plugin/marketplace.json` also has a `version` field — keep both in sync. The test suite (`make test`) validates that commands, agents, and skills match between the two files.
