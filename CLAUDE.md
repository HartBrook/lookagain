# CLAUDE.md

Project-level instructions for Claude Code working in this repo.

## What this is

`lookagain` is a Claude Code plugin (published via the `hartbrook-plugins` marketplace) that runs sequential multi-pass code reviews. The main user-facing surface is the `/look:again` skill.

## Layout

- `src/skills/again/SKILL.md` - orchestrator prompt for `/look:again`
- `src/skills/tidy/SKILL.md` - `/look:tidy` cleanup skill
- `src/skills/lookagain-output-format/SKILL.md` - JSON output contract the reviewer subagent must follow
- `src/agents/lookagain-reviewer.md` - reviewer subagent definition
- `src/dot-claude-plugin/plugin.json` - plugin manifest (becomes `.claude-plugin/plugin.json` in the built dist)
- `.claude-plugin/marketplace.json` - marketplace manifest at repo root (what the marketplace fetches from `main`)
- `scripts/package.sh` - build script (renames `dot-*` -> `.*` and zips)
- `scripts/test.sh` - structural validation
- `evals/promptfooconfig.yaml` - behavioral evals

## Editing rules

- Skill prompts (`src/skills/**/SKILL.md`): use `$ARGUMENTS` (whole string) or `$ARGUMENTS[N]` (positional) only. Do not use `arguments:` frontmatter array or `$ARGUMENTS.<name>` dot-access; neither is interpolated by Claude Code. See CONTRIBUTING.md "Writing Skill Prompts" for the full pattern.
- Every skill that uses `$ARGUMENTS` must have an `argument-hint` in frontmatter, a defaults table in the body, and a "log the resolved configuration" instruction. `make test` enforces this.
- User-triggered skills should set `disable-model-invocation: true` so Claude does not auto-fire them.

## Tests

- `make test` - structural validation, free, offline. Run before every commit.
- `make eval` - behavioral evals via promptfoo. Run after prompt or argument-handling changes. Needs `ANTHROPIC_API_KEY`.
- `make integration` - end-to-end review in a temp repo. Run after pipeline/output-format changes. Needs `ANTHROPIC_API_KEY`.

## Release process

The marketplace tracks `main` of this repo. There are no git tags or GitHub releases - bumping the version on `main` is what makes a new release visible to users.

Checklist for cutting a release:

1. Branch off `main`: `git checkout -b release/vX.Y.Z`.
2. Bump version in **both** manifest files (must stay in sync):
   - `src/dot-claude-plugin/plugin.json` -> `"version": "X.Y.Z"`
   - `.claude-plugin/marketplace.json` -> `"version": "X.Y.Z"` (inside `plugins[0]`)
3. Add a `## [X.Y.Z] - YYYY-MM-DD` section to `CHANGELOG.md` under "Added"/"Changed"/"Fixed"/"Removed" using Keep a Changelog conventions.
4. Run `make test`. Fix anything it flags.
5. (Recommended for skill prompt changes) `make eval`.
6. (Recommended for orchestration/output-format changes) `make integration`.
7. Commit, push, open a PR against `main`.
8. After merge, end users update with:
   ```
   /plugin marketplace update hartbrook-plugins
   /plugin uninstall look@hartbrook-plugins
   /plugin install look@hartbrook-plugins
   ```

### Semver guidance

- **Patch** (0.5.0 -> 0.5.1): bug fixes, doc-only changes, internal refactors.
- **Minor** (0.5.0 -> 0.6.0): new arguments, new skills, new output fields, anything additive.
- **Major** (0.x.0 -> 1.0.0): breaking changes to command names, argument names, or output contracts that downstream tooling parses.

While the project is pre-1.0, breaking changes can also go in a minor bump - call them out clearly in the CHANGELOG under "### Changed" with a "Breaking:" prefix.

## When in doubt

- Read `CONTRIBUTING.md` for human-contributor workflow details.
- Read `README.md` for user-facing behavior.
