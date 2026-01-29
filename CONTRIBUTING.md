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
│   ├── agents/             # Subagent definitions
│   │   └── lookagain-reviewer.md
│   ├── skills/             # Plugin skills (commands + reference)
│   │   ├── again/          # Main orchestrator (/look:again)
│   │   ├── tidy/           # Tidy old review runs (/look:tidy)
│   │   └── lookagain-output-format/  # Output format spec
│   ├── dot-claude-plugin/  # Plugin manifest (becomes .claude-plugin/)
│   └── dot-claude/         # Claude settings (becomes .claude/)
├── scripts/
│   ├── package.sh          # Build script
│   ├── test.sh             # Plugin validation tests
│   └── integration-test.sh # End-to-end integration test
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

# Integration test — end-to-end run of look:again with auto-fix
# Requires ANTHROPIC_API_KEY
make integration
```

The three test layers catch different kinds of regressions:

| Layer | Command | What it catches | Cost |
|-------|---------|----------------|------|
| **Structure** | `make test` | Broken manifests, missing files, frontmatter drift, cross-reference mismatches | Free, offline, fast |
| **Evals** | `make eval` | Model misinterpreting arguments (e.g. ignoring `auto-fix=false`, wrong pass count) | API calls (~$0.05/run) |
| **Integration** | `make integration` | End-to-end failures: review not finding bugs, auto-fix not applying, output artifacts missing, tidy not cleaning up | API calls (~$0.50/run) |

**When to run each:**

- **`make test`** — always, before every commit. It's fast and offline. Catches most structural mistakes from editing manifests, renaming files, or changing frontmatter.
- **`make eval`** — after changing prompt wording or argument handling in skill files. The evals send the interpolated prompts to Claude and assert on behavioral correctness (e.g. that `auto-fix=false` causes the model to skip fixes, that `passes=5` results in 5 planned passes). Cheap enough to run liberally.
- **`make integration`** — after changes that affect the review pipeline end-to-end (orchestration logic, agent prompts, output format). Spins up a temp git repo with contrived bugs, runs `/look:again` with auto-fix, and verifies that bugs are found, fixed, and that output artifacts are correct. Also tests `/look:tidy` cleanup. More expensive, so run when the cheaper layers aren't sufficient.

Both `make eval` and `make integration` require an Anthropic API key. Set it before running:

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

- **[src/skills/again/SKILL.md](src/skills/again/SKILL.md)**: Main orchestrator logic. Controls pass execution, auto-fixing, and aggregation.
- **[src/skills/tidy/SKILL.md](src/skills/tidy/SKILL.md)**: Tidy skill for pruning old review runs.
- **[src/agents/lookagain-reviewer.md](src/agents/lookagain-reviewer.md)**: Reviewer subagent. Defines how individual review passes work.
- **[src/skills/lookagain-output-format/SKILL.md](src/skills/lookagain-output-format/SKILL.md)**: JSON output format specification.
- **[src/dot-claude-plugin/plugin.json](src/dot-claude-plugin/plugin.json)**: Plugin metadata and version.
- **[.claude-plugin/marketplace.json](.claude-plugin/marketplace.json)**: Marketplace manifest for plugin discovery and installation.

### Writing Skill Prompts

When editing or adding skills in `src/skills/`:

- Each skill is a directory containing a `SKILL.md` file (e.g., `src/skills/again/SKILL.md`).
- **Use `$ARGUMENTS` for the raw string.** Claude Code replaces `$ARGUMENTS` with whatever the user typed after the skill name. There is no `$ARGUMENTS.name` dot-access syntax — only `$ARGUMENTS` (whole string) and `$ARGUMENTS[N]` (positional). Do NOT use an `arguments:` array in frontmatter — it is not a supported Claude Code feature and will not be interpolated.
- **Add `argument-hint`** in frontmatter to document expected input format (e.g., `argument-hint: "[key=value ...]"`).
- **Add `disable-model-invocation: true`** for user-triggered actions to prevent Claude from auto-invoking them.
- **Include a defaults table** in the body listing each key, its default, and a description. Instruct the agent to parse `key=value` pairs from `$ARGUMENTS` and fall back to defaults for missing keys.
- **Log the resolved configuration** so it is visible in output and reviewable in evals.
- `make test` enforces that skills using `$ARGUMENTS` have `argument-hint` in frontmatter, a defaults table in the body, and do NOT use the unsupported `arguments:` frontmatter array.
- After changing prompt logic, run `make eval` to verify models still interpret the arguments correctly.

## Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Test locally with `make dev`
5. Commit with a clear message
6. Open a pull request

## Versioning

Update the version in `src/dot-claude-plugin/plugin.json` when making releases. The marketplace entry in `.claude-plugin/marketplace.json` also has a `version` field — keep both in sync. The test suite (`make test`) validates that agents and skills match between the two files.
