---
name: dm812-project-setup
description: Configure a project's local Claude Code setup — detect the stack, ask targeted questions, then write the project's .claude/settings.json (enabledPlugins opt-ins, permission allowlist) and optionally scaffold CLAUDE.md. Use in any new or unconfigured project ("set up this project", "configure claude here", "dm812 setup").
origin: personal-dm812
version: 1.0.0
---

# dm812-project-setup

Heavy or niche plugins are disabled globally and opted into per project.
This skill turns an unconfigured checkout into a locally configured one:
detect what the project is, confirm intent with a few questions, write
`.claude/settings.json`, and leave a summary.

## Step 1 — Detect the stack (no questions yet)

Inspect the repo and build a facts list:

| Signal | Implies |
|---|---|
| `package.json` deps: `expo`/`react-native` | RN app → expo plugin matters, adb QA likely |
| `package.json` deps: `react`/`next`/`vite` (no RN) | web frontend → gsap maybe relevant |
| `supabase/` dir, `@supabase/*` deps, `DATABASE_URL` in `.env*` | supabase + postgres-best-practices |
| `pyproject.toml` / `requirements.txt` | python |
| `go.mod` / `Cargo.toml` / `composer.json` | go / rust / php |
| `CMakeLists.txt`, `*.cpp` | clangd-lsp |
| `gsap` in deps | gsap-skills |
| Mifrat/Base44 references, client-work markers (`.julius/`, `.pika/`) | julius + pika |
| test runner + scripts in `package.json`/`Makefile` | permission allowlist entries |

Also read `~/.claude/settings.json` → `enabledPlugins` for the CURRENT
global on/off state. Never trust a hardcoded list — the baseline drifts.
Anything already `true` globally needs no per-project entry.

## Step 2 — Ask (AskUserQuestion, one round)

Ask only what detection couldn't decide. Typical questions:

1. **Opt-in plugins** (multiSelect, prechecked by detection): julius+pika
   (client delivery work?), supabase/postgres (DB planned?), clangd-lsp,
   gsap-skills.
2. **Device QA**: will a physical Android device be used via adb?
   (→ allowlist `adb` and note `dangerouslyDisableSandbox` need).
3. **Anything else to allowlist**: deploy CLIs, cloud CLIs, etc.

Skip the round entirely if detection is unambiguous and the user asked
for a non-interactive setup.

## Step 3 — Write `.claude/settings.json` in the project

Merge with any existing file — never clobber user content. Shape:

```json
{
  "enabledPlugins": {
    "supabase@claude-plugins-official": true
  },
  "permissions": {
    "allow": [
      "Bash(npm run test:*)",
      "Bash(npm run lint)",
      "Bash(npm run typecheck)",
      "Bash(npx expo *)",
      "Bash(adb *)"
    ]
  }
}
```

Rules:
- `enabledPlugins`: ONLY the opt-ins this project needs (plugins that are
  `false` globally). Do not re-list globally-enabled ones.
- `permissions.allow`: the project's actual quality-gate commands (read
  them from `package.json` scripts / `Makefile`) plus confirmed extras.
  Read-only git commands are already covered globally.
- Use exact plugin keys (`name@marketplace`) as found in the global file.

## Step 4 — CLAUDE.md / AGENTS.md

If the project has neither, offer to scaffold one (or point to `/init`):
project shape, run commands, quality gates, skills to load. Keep it
token-lean; do not duplicate what the code already says.

## Step 5 — Report

Summarize: detected stack, plugins opted in (and why), allowlist entries
written, and anything deliberately left off. Remind that a restart picks
up plugin changes.
