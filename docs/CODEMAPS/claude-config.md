<!-- Generated: 2026-07-17 | Files scanned: common/claude/** | Token estimate: ~600 -->

# Claude Code config surface

`common/claude/` is the source of truth for the portable Claude Code setup.
`install.sh` symlinks each item into `~/.claude/` (`ln -sfn`; real file/dir backed up as `*.pre-dotfiles`).
Edits in the repo are live immediately, on any machine (incl. macOS).

## Linked items (→ ~/.claude/)

```
settings.json           statusline, hooks, permissions, enabled plugins/marketplaces ($HOME paths)
CLAUDE.md               global instructions (all projects)
statusline-command.sh   statusline renderer
hooks/                  claude-notify.sh, hooks.json
scripts/                hook runners + orchestration (hooks/, lib/, *.js referenced by settings)
skills/                 16 SKILL.md dirs (dm812-*, emil-design-eng, material-3, learned, ...)
commands/               11 slash commands (docs, e2e, eval, orchestrate, tdd, verify, ...)
rules/                  89 files: common/ + per-language (typescript, python, golang, web, ...) + zh/
```

## rules/ layering (see rules/README.md)

```
common/       language-agnostic principles (always)
<lang>/       extends common (typescript python golang java kotlin rust swift php cpp csharp dart perl web)
zh/           Chinese translation of common
```

Precedence: language-specific overrides common (CSS-specificity style).

## NOT synced (on purpose)

```
~/.claude.json                 OAuth / MCP servers — secrets + machine state
~/.claude/settings.local.json  machine-local overrides
~/.claude/plugins/             Claude Code reinstalls from enabledPlugins + extraKnownMarketplaces
```

Caveat: `pika-dev` marketplace `directory` in settings.json is inherently machine-specific.
If Claude Code replaces the settings.json symlink with a plain file, re-run `install.sh` and commit drift.
