---
name: dm812-memory-audit
description: Audit and report on Claude Code's persistent learning surfaces — auto-memory files, instincts (continuous-learning-v2), session stash, plans, and learning hooks. Use when the user wants to understand what is remembered, where, whether instincts/observers are enabled, and what is stale or duplicated.
origin: personal-dm812
version: 1.0.0
---

# dm812-memory-audit

Generates a structured audit report of every place Claude Code stores accumulated experience for the current user, and per project. The goal is to give the user a clear picture of:

1. **What is remembered** — auto-memory files, their types, age, freshness.
2. **Where it lives** — global vs. project-scoped surfaces.
3. **What is enabled** — instincts (continuous-learning-v2), observer hooks, learning hooks.
4. **What is stale** — old, duplicate, or contradictory entries.
5. **What to do next** — concrete cleanup / activation suggestions.

## When to invoke

- User asks: "what do you remember?", "audit my memory", "где у меня инстинкты включены", "покажи отчёт по памяти".
- After a long break from a project — check for staleness.
- Before sharing config or onboarding a teammate — check for leaked secrets in memory files.
- After running `/learn`, `/instinct-status`, or major refactors — verify state.

## Surfaces to inspect

Inspect ALL of the following. Mark each as **PRESENT / EMPTY / NOT CONFIGURED**.

### A. Auto-memory (per-project)

- Path: `~/.claude/projects/<encoded-project-path>/memory/`
- Files to read: `MEMORY.md` (index) + every `*.md` (entries).
- Per file, extract `name`, `description`, `type` from frontmatter.
- Detect:
  - Total count, breakdown by type (`user` / `feedback` / `project` / `reference`).
  - Entries older than 60 days (mtime) — flag as candidates for review.
  - Entries referenced in `MEMORY.md` but missing on disk, and vice versa.
  - Duplicate or near-duplicate `description` fields.
  - Entries that violate the "do not save" rules (commit-style logs, ephemeral task state, code patterns derivable from the repo).
- The current project's memory dir is the one matching `cwd` — derive it from the system reminder showing `Contents of <PROJECT>/CLAUDE.md` or by listing `~/.claude/projects/` and matching the path.

### B. Global instructions

- `~/.claude/CLAUDE.md` — present? size? last modified?
- `~/.claude/rules/common/*.md` and `~/.claude/rules/<lang>/*.md` — list installed rule sets.
- `~/.claude/AGENTS.md` — present?

### C. Project instructions

- `<project>/CLAUDE.md` — present? size?
- `<project>/.claude/settings.json` or `settings.local.json` — exists?

### D. Instincts (continuous-learning-v2)

- Skill SKILL.md: `~/.claude/skills/continuous-learning-v2/SKILL.md`
- Config: `~/.claude/skills/continuous-learning-v2/config.json` — read `observer.enabled`, `run_interval_minutes`, `min_observations_to_analyze`.
- Project registry: `~/.claude/homunculus/projects.json` — list known projects, last_seen, root path.
- Personal instincts: `~/.claude/homunculus/instincts/personal/` — count, list names.
- Inherited instincts: `~/.claude/homunculus/instincts/inherited/` — count.
- Project-scoped instincts: `~/.claude/homunculus/instincts/<project-id>/` (if exists) — count for current project.
- Evolved artifacts: `~/.claude/homunculus/evolved/` — count of promoted skills/commands/agents.
- Observer log: `~/.claude/homunculus/observer.log` — last entry timestamp (is it actually running?).

### E. Hooks that feed learning

Read `~/.claude/settings.json` and any project `settings.json`. Look for hooks whose command path contains `homunculus`, `observe`, `instinct`, `learn`, `continuous-learning`. For each:
- Event (PreToolUse / PostToolUse / Stop / SessionStart).
- Matcher pattern.
- Whether the script file actually exists.

### F. Sessions and plans

- `~/.claude/session-data/` — count, most recent timestamp.
- `~/.claude/sessions/` — count.
- `~/.claude/plans/` — count, most recent.
- `~/.claude/tasks/` — count.

### G. Skills inventory (lightweight)

- Count of skills in `~/.claude/skills/` (top-level dirs).
- Count of plugin skills under `~/.claude/plugins/`.
- Highlight learning-related skills present: `continuous-learning`, `continuous-learning-v2`, `learn`, `learn-eval`, `evolve`, `instinct-status`, `instinct-export`, `instinct-import`, `strategic-compact`, `save-session`, `resume-session`.

## Report format

Output a single Markdown report in the user's language. Use this skeleton:

```
# Memory & Learning Audit — <YYYY-MM-DD>

## TL;DR
- <3–6 bullets: most important findings, e.g. "instincts включены, но за 7 дней 0 новых наблюдений">

## 1. Auto-memory (project: <name>)
| Type | Count | Stale (>60d) |
|---|---|---|
| user | … | … |
| feedback | … | … |
| project | … | … |
| reference | … | … |

Entries:
- [filename](path) — type — last modified — one-line description
…

Issues:
- <missing from index / orphaned files / suspected duplicates / rule violations>

## 2. Global instructions
- ~/.claude/CLAUDE.md — <size, mtime>
- Rules installed: common, web, zh (…)

## 3. Project instructions
- <project>/CLAUDE.md — <size, mtime>
- Project settings.json — <yes/no>

## 4. Instincts (continuous-learning-v2)
- Observer: enabled=<true/false>, interval=<N>m, min_obs=<N>
- Observer log last line: <timestamp> (<X hours ago>)
- Personal instincts: <count>
- Inherited: <count>
- Project-scoped (<project>): <count> — list names
- Evolved artifacts: <count>
- Verdict: <RUNNING / IDLE / NOT CONFIGURED>

## 5. Learning hooks
| Event | Matcher | Script | Exists? |
|---|---|---|---|
…

## 6. Sessions, plans, tasks
- session-data: <N>, latest <date>
- plans: <N>, latest <date>
- tasks: <N>

## 7. Skills inventory
- Total skills: <N> (user) + <N> (plugins)
- Learning-related present: <list>
- Missing/recommended: <list>

## Recommendations
1. <actionable, ranked by impact>
2. …
```

## Implementation steps

1. Resolve current project memory dir from `cwd` → encoded path under `~/.claude/projects/`.
2. `Bash` listings + `Read` for each surface above. Prefer one combined `Bash` invocation per section to keep the audit fast.
3. Frontmatter parsing: simple grep for `^name:`, `^type:`, `^description:` is enough — do not require a YAML parser.
4. Stale threshold: 60 days by default. Surface entries with `mtime < now - 60d`.
5. For the observer "running?" check: read the **last** line of `observer.log`. If older than 2× `run_interval_minutes`, mark IDLE.
6. Never read or print contents of files that look like secrets (`.env`, `credentials*`, `*.key`). If found inside memory, flag as CRITICAL.
7. Keep the report under ~250 lines. Truncate long lists and link to paths.

## Output rules

- Do not modify any files. This skill is read-only by default.
- If the user asks to clean up after the report, do that as a separate, explicit step — never auto-delete.
- Match the user's language (русский if the request was in Russian).
- End with **Recommendations**, ranked by impact, each one actionable in a single command or edit.

## Out of scope

- Editing or rewriting memory entries (use `/learn`, `/learn-eval`, or direct edits).
- Promoting instincts to skills (use `/evolve`).
- Cross-project consolidation (separate task).
