# Codex Sync

`common/codex/` is the source of truth for the portable Codex baseline.
`common/codex/codex-sync.sh` applies it idempotently and is linked into
`~/bin` as `codex-sync` by `install.sh`.

## What Syncs

```
AGENTS.md                  -> ~/.codex/AGENTS.md
skills/dm812-project-setup -> ~/.codex/skills/dm812-project-setup
skills/dm812-memory-audit  -> ~/.codex/skills/dm812-memory-audit
config.toml baseline       -> merged into ~/.codex/config.toml
```

The config merge manages only the baseline values in `common/codex/config.toml`:

```
personality = "pragmatic"
model = "gpt-5.5"
model_reasoning_effort = "medium"

mcp_servers.base44
mcp_servers.context7
mcp_servers.Jam
mcp_servers.mobbin
```

## Requirements

The TOML merge needs `python3` >= 3.11 (`tomllib`). Stock macOS ships no
`python3` at all, so both the missing-interpreter and too-old cases **warn and
continue** rather than aborting — a non-zero exit here would kill `codex-sync`
under `set -e`, and with it the tail of `install.sh`, after `AGENTS.md` and the
skills had already been linked. Symlinking always happens; only the merge is
skipped, and re-running `codex-sync` later applies it.

## What Is Preserved

`~/.codex/config.toml` is not symlinked or replaced. `codex-sync` preserves
manual Codex state such as:

```
trusted projects
manually installed/enabled plugins
existing MCP servers such as figma and supabase
feature flags
TUI/statusline settings
auth and credential-store choices
future Codex changes written by the CLI/app
```

If you install a Codex plugin manually, Codex may update `~/.codex/config.toml`
on that machine. Running `codex-sync` keeps that plugin entry, but it does not
automatically commit the plugin into dotfiles. To sync a manual change across
machines, add the desired stable baseline entry to `common/codex/config.toml`
after reviewing it.

## Intentionally Not Migrated

```
Claude slash commands
Claude hooks
Claude rules
Claude settings.json
Claude statusline
Claude plugin marketplace config
Claude credentials, OAuth tokens, plugin cache, sessions, and local settings
Pika orchestrator
Julius plugin setup
```

Pika and Julius are intentionally left out. Pika will get a Codex-specific
orchestrator later; Julius will be installed manually.
