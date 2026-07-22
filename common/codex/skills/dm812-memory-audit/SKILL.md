---
name: dm812-memory-audit
description: Audit Codex's persistent local surfaces: config, AGENTS.md files, skills, plugins, MCP servers, memories, logs, sessions, and trusted projects. Use when the user asks what Codex remembers or how Codex is configured locally.
origin: personal-dm812
version: 0.1.0
---

# dm812-memory-audit

Audit Codex persistent state without exposing secrets. Treat credentials and tokens as present-or-absent metadata only; never print their contents.

## Surfaces To Inspect

Inspect these surfaces when present:

- `~/.codex/config.toml`: model defaults, features, MCP servers, plugins, trusted projects, statusline settings.
- `~/.codex/AGENTS.md`: global Codex instructions.
- Project `AGENTS.md` and `.codex/config.toml`: repo-local instructions and trusted project config.
- `~/.codex/skills/`: user, system, and locally synced skills.
- `~/.codex/plugins/` and plugin-related config entries: installed or enabled plugins.
- `~/.codex/memories_*.sqlite`, `history.jsonl`, `session_index.jsonl`, and logs: counts, freshness, and locations only.
- `codex mcp list`: configured MCP servers and status.

## Report Format

Return a concise audit with:

1. **Configured Defaults**: model, reasoning, personality, web/search or feature flags when present.
2. **Instructions**: global and project instruction files found.
3. **Skills And Plugins**: installed skills, plugin config entries, and obvious missing or duplicated surfaces.
4. **MCP**: server names and auth/status, without tokens.
5. **Memory And Session State**: counts and freshness, not contents unless the user explicitly asks.
6. **Risks And Cleanup**: stale entries, duplicate skills, unknown synced files, or config that should remain machine-local.
