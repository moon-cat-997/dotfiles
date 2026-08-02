---
name: dm812-project-setup
description: Configure a project's local Claude Code setup — detect the stack, ask targeted questions, then write the project's .claude/settings.json / settings.local.json (plugin opt-ins, permission allowlist) and optionally scaffold CLAUDE.md. Use in any new or unconfigured project ("set up this project", "configure claude here", "dm812 setup"). Pass --yes for non-interactive setup.
origin: personal-dm812
version: 1.1.0
---

# dm812-project-setup

Heavy or niche plugins are disabled globally and opted into per project.
This skill turns an unconfigured checkout into a locally configured one —
and re-runs safely on an already-configured one (UPDATE mode).

Authoring rule: bump minor version on any behavioral change to detection,
questions, or written output. Git history is the changelog — no changelog
section in this file.

## Step 0 — Mode

If `.claude/settings.json` or `.claude/settings.local.json` already
exists, run in UPDATE mode: read both as the baseline, read the baseline
memory record (see Step 5) if present, compute only the delta, show a
diff of each file before writing, and never remove or rewrite existing
entries. Do not re-ask anything the baseline record lists under
"deliberately omitted" unless detection found a NEW signal since that
run. Invariant: running the skill twice in a row must write nothing the
second time to the settings files or CLAUDE.md (the Step 5 baseline
record may update its run date) — if a second run would change a
settings file, the merge logic is wrong.

Legacy audit (UPDATE mode): audit every EXISTING entry against the
current Step 3 syntax, content, and routing rules. List each violation
in the Step 5 report (entry, rule violated, suggested replacement).
Removing, rewriting, or migrating an existing entry is allowed ONLY with
the user's explicit per-entry confirmation in the Step 2 round — the
single sanctioned exception to never-remove. Record declined fixes under
"deliberately omitted" so later runs re-flag them in the report without
re-asking.

Also run `git worktree list`. If cwd is a linked worktree, ask whether
to write into the main worktree's `.claude/` (usually yes — Claude Code
reads `settings.local.json` from the repo root, resolved through
worktrees to the main checkout, so one file covers every worktree). If
path-anchored rules are written to it, note that a `/path` rule in local
settings resolves against the directory the session was started from,
i.e. per-worktree.

## Step 1 — Detect (no questions yet)

Read `~/.claude/settings.json` IN FULL — not just `enabledPlugins`:

- `enabledPlugins` + `extraKnownMarketplaces` → current opt-in state and
  the exact `name@marketplace` keys. Never trust a hardcoded list — the
  baseline drifts. Anything already `true` globally needs no entry.
- `permissions` (`allow` / `deny` / `ask` / `defaultMode`) → build the
  "globally covered" set. If allow contains `Bash` / `Bash(*)` or
  `defaultMode` auto-approves, every project Bash allow entry is
  currently inert — allow rules union across scopes, and only deny/ask
  rules can tighten below the global baseline. Don't silently write dead
  entries; surface it (Step 2 question 4, Step 5 report).

Checkout-path taxonomy (outranks marker dirs when they disagree):
`~/Projects/Own/*` = personal — never precheck julius.
`~/Projects/JuliusAgency|Lanit|FL/*` = client work — precheck julius+pika.

Evaluate the repo against this table. Action types — `opt-in:` a
globally-false plugin; `allow:`/`ask:` permission entries; `note:` a
report or CLAUDE.md remark.

| Signal | Action |
|---|---|
| `expo`/`react-native` deps | note: RN app — adb QA likely (see adb row) |
| `supabase/` dir, `@supabase/*` deps, `DATABASE_URL` in `.env*` | opt-in: supabase + postgres-best-practices |
| `.pika/` dir, `.pika/` in committed `.gitignore`, or pika history in project memory | opt-in: pika ONLY (not julius) |
| `.julius/` dir, Mifrat/Base44 references, julius registry.json | opt-in: julius (+ pika only if client delivery confirmed in Step 2) |
| `gsap` in deps | opt-in: gsap-skills |
| `CMakeLists.txt`, `*.cpp` | opt-in: clangd-lsp |
| `eas.json`, `.eas/workflows/`, `eas-cli` in devDeps | allow: `eas` OR `npx eas` — one spelling, matching how scripts invoke it (→ settings.local.json); ask: `eas build` / `eas submit` |
| scripts in `package.json`/`Makefile`/`justfile`/`Taskfile.yml`, plus commands run by `.github/workflows/*.yml` / `.eas/workflows/*` | allow: the quality-gate commands. CI is the authoritative gate list — prefer what CI actually runs over guessing from script names |
| `pnpm-workspace.yaml` / `turbo.json` / `nx.json` / `workspaces` in package.json | allow: `pnpm` / `turbo run` / `nx`; write settings at repo root |
| `gradlew` / `*.gradle.kts` (incl. `android/` in bare RN) | allow: `./gradlew` |
| `pyproject.toml` / `requirements.txt` | allow: `pytest`, `uv run`, `ruff` |
| `go.mod` | allow: `go test` / `go build` / `go vet` |
| `Cargo.toml` | allow: `cargo` |
| `composer.json` | allow: `composer` |
| `.env*` present | note: verify global deny `Read(.env*)` still exists; add a project deny only if the global rule is gone |
| adb on PATH and `adb devices` lists a device, OR project memory documents device QA | allow: `adb` (→ settings.local.json); skip the Step 2 adb question |

Marker dirs (`.pika/`, `.julius/`, `.impeccable/`) are usually
gitignored — absence on a fresh clone proves nothing. The committed
`.gitignore` line naming them is the clone-stable evidence.

If a detected stack has no row, scan global `enabledPlugins` for a
name-matching disabled plugin before concluding there is nothing to
opt in.

## Step 2 — Ask (AskUserQuestion, one round)

Ask only what detection couldn't decide. Typical questions:

1. **Opt-in plugins** (multiSelect, prechecked by detection): julius and
   pika as SEPARATE options; supabase/postgres; clangd-lsp; gsap-skills.
2. **Device QA** — only when the stack is mobile AND detection found no
   attached device and no memory evidence; phrase as a prechecked
   confirmation, not an open question. A yes routes `adb` to
   settings.local.json; carry the sandbox caveat forward to Step 5.
3. **Anything to allowlist, ask-gate, or deny**: deploy/cloud CLIs, and
   whether the project routinely reads a sibling repo (shared kit,
   reference app, plugin source) → on yes, write
   `permissions.additionalDirectories` (absolute path → settings.local.json).
4. If the global baseline is fully permissive (`Bash(*)`): write the
   NEW candidate allow entries anyway as documentation /
   future-tightening insurance, or skip them? (In UPDATE mode this
   governs only entries not yet present; existing entries are handled by
   the legacy audit.)

Non-interactive: skip the round ONLY when the invocation args contain
`--yes` (or the user's message literally says no questions) — never
infer non-interactive from tone. `--yes` defaults: opt in only plugins
with a concrete detection signal (marker file or dependency, not "maybe
relevant"); write only allow entries derived from scripts/CI; skip adb,
deploy CLIs, and all extras; list every skipped question and its applied
default in the report.

## Step 3 — Write the settings file(s)

FIRST invoke `Skill(update-config)` and follow its current rules for
permission-rule syntax, settings.json vs settings.local.json routing,
and merge behavior — the shape below is illustrative, not canonical.
If update-config's guidance conflicts with any rule below, update-config
wins — the Routing/Syntax/Content lists here are this skill's checklist
snapshot, not an override.

Routing — which file gets an entry:

- `.claude/settings.json` (committed, shareable): stack-derived portable
  rules any contributor benefits from — package-script commands,
  `npx expo`, expo-doctor, opt-ins for plugins from public marketplaces.
- `.claude/settings.local.json` (machine-local; auto-gitignored only
  when Claude Code itself creates it — files this skill writes rely on
  the Step 4.5 gitignore check): anything
  tied to THIS machine or user — rules containing an absolute path,
  device tooling (`adb`), credentialed deploy CLIs (`eas`), opt-ins for
  plugins from directory-sourced personal marketplaces (e.g. pika),
  `additionalDirectories`.

`.claude/settings.json` (committed):

```json
{
  "enabledPlugins": { "supabase@claude-plugins-official": true },
  "permissions": {
    "allow": ["Bash(npm run lint)", "Bash(npm run test*)", "Bash(npx expo *)"]
  }
}
```

`.claude/settings.local.json` (machine-local):

```json
{
  "permissions": {
    "allow": ["Bash(eas *)", "Bash(adb *)"],
    "ask": ["Bash(eas build *)", "Bash(eas submit *)"]
  }
}
```

Syntax rules:

- `Bash(x *)` and `Bash(x:*)` are EQUIVALENT — prefix plus word boundary
  (space or end-of-string). Neither `Bash(npm run test *)` nor
  `Bash(npm run test:*)` matches `npm run test:coverage`.
- `Bash(x*)` (no space before `*`) has no boundary — use it for
  colon-namespaced script families: `Bash(npm run test*)` matches
  `test`, `test:watch`, `test:coverage`.
- `*` may appear at any position and spans spaces. Compound commands
  (`&&`, `||`, `;`, `|`, `&`) are split and each subcommand must match
  some rule.
- `npx cmd` needs its own rule, separate from `cmd`. Pick ONE spelling
  per CLI — the one scripts/AGENTS.md actually use — never emit both.
- NEVER embed an absolute filesystem path in a rule; treat any `/home/`
  or `/Users/` substring in a candidate as an error. Use a wildcard
  segment (`Bash(npm --prefix * run *)`) or route the exact rule to
  settings.local.json.

Content rules:

- `enabledPlugins`: ONLY globally-false plugins this project needs, with
  exact `name@marketplace` keys copied from the global file. Never flip
  an existing value — an explicit `false` in the project file is a user
  opt-out and beats detection.
- Never allowlist a CLI without a detection signal, transcript evidence,
  or an explicit Step 2 confirmation.
- Deploy/cloud CLIs: allow the namespace, then `ask`-gate money-spending
  or publishing subcommands (ask beats allow). deny/ask rules are the
  only way to tighten below a broad global allow.
- If the project has prior session history, run
  `Skill(fewer-permission-prompts)` and merge its transcript-mined
  candidates (including `mcp__server__tool` rules) — evidence beats
  guessing.
- Merge (UPDATE mode): parse existing JSON first — if it fails, stop and
  report, never overwrite. Preserve every key you don't manage (hooks,
  env, deny, unknown keys) verbatim. `allow` = set-union with
  exact-string dedupe; skip a new entry an existing broader rule already
  covers; append, never reorder or delete.
- Delta and dedupe span BOTH settings files: an entry (allow rule or
  enabledPlugins key) present in either file counts as already present.
  Never duplicate an entry into its routed file while it exists in the
  other — flag the misplacement via the legacy audit instead.

## Step 4 — CLAUDE.md / AGENTS.md

If the project has neither, offer to scaffold one (or point to `/init`):
project shape, run commands, quality gates, skills to load. Token-lean;
do not duplicate what the code already says.

Independently of scaffolding: if device QA was confirmed (or detected in
Step 1) and the existing CLAUDE.md/AGENTS.md does not document the adb
workflow, offer to append it (device serial conventions, runs
unsandboxed).

## Step 4.5 — Verify (before reporting)

1. Parse every file written (`jq .` or equivalent).
2. Cross-check each `enabledPlugins` key verbatim against the global
   file's `enabledPlugins` / `extraKnownMarketplaces` — a typo'd
   `name@marketplace` is a silent no-op.
3. Check each written allow entry against the globally-covered set —
   still write shadowed entries when the user chose future-proofing in
   Step 2, but flag each as currently redundant.
4. Git hygiene: if settings.local.json was written, ensure the REPO's
   `.gitignore` covers `.claude/settings.local.json` (do not rely on the
   user's global git ignore — teammates don't have it); offer to append.
   Run `git status` on settings.json and state its tracked/untracked
   status in the report. Never `git add` anything yourself.
5. UPDATE mode: fold the Step 0 legacy-audit results (existing entries
   violating current rules) into the report data.

## Step 5 — Report

Summarize: detected stack; plugins opted in (and why); each written
entry with its live-or-shadowed status; legacy-audit violations (UPDATE
mode); anything deliberately left off. Note that allow rules in the
shared settings.json take effect only after the workspace trust dialog
is accepted; settings.local.json entries generally bypass that check.
For a brand-new project with no session history, note that re-running
`Skill(fewer-permission-prompts)` after a week of real sessions will
catch what static detection missed.

Always end with a **Not added, and why** block, as applicable:
(a) Read/Grep/Glob are built-in tools — they never prompt inside the
project; (b) the built-in read-only Bash set (ls, cat, grep, find, head,
diff, read-only git, …) runs without a prompt in every mode — the set
itself is not configurable, though an explicit ask/deny rule can still
force a prompt for one of them; (c) web
access is governed by `WebFetch(domain:…)` rules, not Bash; (d) MCP
tools use `mcp__server__tool` / `mcp__server__*` rules — list any
exposed by newly opted-in plugins; (e) sandbox-escape requests
(`dangerouslyDisableSandbox`, e.g. adb device control) go through the
regular permission flow — a confirmation prompt in default mode, the
classifier (often no prompt) in auto mode; no allow rule can target the
parameter (parameter rules are deny/ask-only). To force a prompt on
every unsandboxed retry add ask: `Bash(dangerouslyDisableSandbox:true)`;
to remove friction for a trusted tool, point at
`sandbox.excludedCommands`.

Reload guidance: new opt-ins don't activate in the running session
automatically — tell the user to run `/reload-plugins` (applies
enable/disable changes without restarting) or start a fresh session,
then verify the opt-in took: the plugin's skills should appear in the
available-skills list. If they don't, the likely cause is a wrong
`name@marketplace` key — re-check it against the global file.

Persist the baseline record: write/update the project auto-memory file
`claude-setup-baseline.md` (run date, detected facts, each decision with
a one-line rationale, and a "deliberately omitted" section covering
declined plugins, declined allow entries, and skipped questions), and
index it in MEMORY.md — so future runs diff instead of re-asking.

## Failure modes

- Global `~/.claude/settings.json` missing or unparsable: report it and
  ask the user for the baseline; never assume a default plugin roster or
  permission state.
- Chosen plugin key not found in global `enabledPlugins` /
  `extraKnownMarketplaces`: do NOT invent a `name@marketplace` — confirm
  the exact key first; a wrong key fails silently.
- Existing project settings unparsable: stop, show the parse error,
  never overwrite.
