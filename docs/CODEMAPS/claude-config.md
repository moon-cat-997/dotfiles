<!-- Generated: 2026-07-18 | Files scanned: common/claude/** | Token estimate: ~680 -->

# Claude Code config surface

`common/claude/` is the source of truth for the portable Claude Code setup.
`common/claude/claude-sync.sh` (the "button", linked into `~/bin` as `claude-sync`,
also called at the end of `install.sh`) applies it all, idempotently.
Edits in the repo are live immediately, on any machine (incl. macOS).

## claude-sync.sh (72 lines) — what it does

```
1. Symlink each item → ~/.claude/ (ln -sfn)
     real file/dir backed up once as *.pre-dotfiles
     DRIFT REPAIR: if a symlink was replaced by a plain file differing from
       repo (Claude Code rewriting settings.json), save as
       <item>.drift-<timestamp> + warn to diff, then relink
2. Register user-scope MCP servers from mcp-servers.conf:
     claude mcp get <name> || claude mcp add --scope user --transport http <name> <url>
     NO login — servers OAuth lazily on first use in a session
     claude not on PATH → skip with notice (don't fail)
3. Linux + no ~/.claude/.credentials.json → hint to run `claude` once
```

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

`mcp-servers.conf` — NOT linked; read by claude-sync. `name url` per line (all HTTP):
`base44 context7 Jam mobbin`. Add a server = add a line + run `claude-sync`.

## rules/ layering (see rules/README.md)

```
common/       language-agnostic principles (always)
<lang>/       extends common (typescript python golang java kotlin rust swift php cpp csharp dart perl web)
zh/           Chinese translation of common
```

Precedence: language-specific overrides common (CSS-specificity style).

## NOT synced (on purpose)

```
~/.claude.json                 machine state; MCP servers restored from mcp-servers.conf instead
~/.claude/.credentials.json    OAuth tokens (macOS: Keychain) — one-time `claude` login per machine
~/.claude/settings.local.json  machine-local overrides
~/.claude/plugins/             Claude Code reinstalls from enabledPlugins + extraKnownMarketplaces
```

Caveat: `pika-dev` marketplace `directory` in settings.json is machine-specific
(plugin inactive until `~/Projects/Own/pika-orch` exists). settings.json symlink
drift is auto-repaired by claude-sync (see above).
