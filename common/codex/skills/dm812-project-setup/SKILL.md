---
name: dm812-project-setup
description: Configure a project's local Codex setup by detecting the stack, proposing native Codex files, and writing only approved project-local `.codex/config.toml` or `AGENTS.md` guidance. Use for new or unconfigured projects when the user asks to configure Codex for the repo.
origin: personal-dm812
version: 0.1.0
---

# dm812-project-setup

Configure a project for Codex using native Codex surfaces. Do not copy Claude Code settings, plugin entries, slash commands, or hooks into the project.

## Workflow

1. Detect project context before asking questions:
   - read root and nested `AGENTS.md`, `README.md`, `CONTRIBUTING.md`, and project docs;
   - inspect package manifests, lockfiles, framework markers, CI workflows, and test scripts;
   - identify MCP needs from real project evidence, not from assumptions.
2. Report the detected stack, validation commands, and missing decisions.
3. Ask only for choices that cannot be discovered locally.
4. Prefer small project-local additions:
   - `AGENTS.md` for repo conventions, commands, verification steps, and review expectations;
   - `.codex/config.toml` only for project-scoped Codex settings that are safe in a trusted repo.
5. Do not write provider auth, credentials, notification commands, profile selection, or machine-local settings into project config.
6. Show planned file changes before writing if the project already has Codex config.

## Output

End with:

- detected stack;
- files created or changed;
- commands Codex should use for validation;
- MCP or plugin setup that remains manual;
- anything deliberately skipped.
