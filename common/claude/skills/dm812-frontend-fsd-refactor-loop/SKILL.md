---
name: dm812-frontend-fsd-refactor-loop
description: Autonomous overnight refactoring of an FSD (Feature-Sliced Design) frontend, layer by layer, from shared/ up through app/. Aligned with FSD 2.1 (pages-first, public-API/@x rules, Steiger gate). Combines architect → refactor-cleaner → code-reviewer agents with verify-gates between layers. Safe to launch unattended. Use when the user wants senior-level code quality, dedup, single-source-of-truth, dead-code removal across the whole frontend.
origin: personal-dm812
---

# dm812-frontend-fsd-refactor-loop

Multi-layer FSD refactor orchestration. Encodes the layer-by-layer flow we used on polybet (commits 5ffebef → fd8f1a6) plus safeguards we wished we had on the first pass. Aligned with the official FSD 2.1 docs (feature-sliced.design) — see the canon section below.

## FSD 2.1 canon this loop enforces

These rules go **verbatim into every architect prompt** and back the verify-gate checks. Source: feature-sliced.design docs, v2.1.

1. **Layers** (top → bottom): `app → pages → widgets → features → entities → shared`. Import rule: a module may import only from layers **strictly below** its own. `processes/` is deprecated — if present, never add to it; plan its migration into `features/`/`app/` (Layer 6 scope).
2. **Slices**: `pages/widgets/features/entities` are sliced by business domain; **`app/` and `shared/` have no slices** — they split directly into segments, and their segments may reference each other freely.
3. **Segments** are named by purpose (`ui`, `api`, `model`, `lib`, `config`), never by essence — `components/`, `hooks/`, `types/`, `utils/` inside a slice are rename targets.
4. **Public API**: every slice exposes an explicit `index.ts` contract. From outside the slice: no deep imports past the index, and no `export *` wildcard re-exports in the index. Exception: `shared/ui` and `shared/lib` use a **per-component index** (no monolithic barrel) for tree-shaking. Inside a slice, use relative full-path imports (importing your own index invites circular deps).
5. **Same-layer slice imports are forbidden** — with one sanctioned escape hatch: cross-entity references via `@x` notation (`entities/A/@x/B.ts`, imported as `entities/A/@x/B`, read "A crossed with B"). Keep them rare and entities-only.
6. **Pages-first (the 2.1 shift)**: decomposition starts at pages and may legitimately stop there. An entity/feature/widget consumed by only **one** page should be **merged into that page**, not kept as a slice. Extraction is justified by real reuse (≥ 2 pages), never by anticipation. Fat pages are not a smell if the team can navigate them.
7. **Widgets** exist only for large self-sufficient blocks reused across pages (or router-level blocks in nested routing). A block that is most of one page's content and never reused belongs in the page.
8. **Steiger** (`steiger` + `@feature-sliced/steiger-plugin`) is the official FSD architecture linter; this loop runs it as a per-layer regression gate alongside knip (rules like `fsd/forbidden-imports`, `fsd/public-api`, `fsd/excessive-slicing`, `fsd/no-ui-in-app`, `fsd/insignificant-slice`).

## When to invoke

User asks for: "refactor whole frontend", "clean up codebase", "make it look like a senior wrote it", "run overnight", "dedup everywhere", or names this skill explicitly.

Pre-conditions you MUST check before starting:
1. Repo is a git repo with a clean working tree (`git status --porcelain` empty). Exception: `--resume` with a crashed `in_progress` layer — see "Resume protocol".
2. Project follows FSD or a layered architecture with these or equivalent dirs: `src/{app,pages,widgets,features,entities,shared}/`. If layout differs, ask the user to confirm the layer order before starting. If `src/processes/` exists, note it in state.json — the layer is deprecated in FSD 2.1 and its migration into `features/`/`app/` is Layer 6 scope (never touched when Layer 6 is skipped).
3. Build/lint/test commands are known (read `package.json` `scripts`). If you can't tell, ask once before starting.
4. There is a recognised package manager (npm/pnpm/yarn/bun). Default to `npm` when there is no lockfile or more than one lockfile.

## Run mode (attended / unattended)

The orchestrator is an LLM: it cannot wait N seconds for a reply and then "default", and it cannot detect Ctrl+C. Therefore run mode is an **explicit input decided once at pre-flight**, recorded as `state.json.mode`:

- `unattended` — the user passed `--unattended`, or their launch phrasing says so ("run overnight", "запусти на ночь", launching right before leaving). In this mode the skill NEVER asks a question mid-run: every ask-or-default branch takes the safe default immediately and logs the decision to `state.json` and SUMMARY.md.
- `attended` — the user is present. Questions are allowed, but ALL of them are asked during pre-flight (while the user is still at the keyboard), never in the middle of the loop.
- Genuinely ambiguous → ask once at pre-flight ("Will you be around, or is this an overnight run?"). A pre-flight question can never strand an overnight run — the user is by definition present at launch time.

## Output location for artifacts

Artifacts live **inside the project repo** so they're easy to browse in the IDE alongside the diff. Create:

```
<project-root>/.refactor-report/<session-id>/
  baseline-build.txt
  baseline-lint.txt
  baseline-tests.txt
  baseline-knip.txt
  baseline-steiger.txt
  knip-after-layer<N>.txt
  steiger-after-layer<N>.txt
  architect-layer<N>.md
  cleaner-layer<N>.md
  reviewer-layer<N>.md
  codemaps-output.txt          # Layer 8 generator output (if run)
  state.json                   # current layer + status (for resume)
  HALT.md                      # written only on halt
  SUMMARY.md                   # final digest (written at end of run)
```

These names are canonical — use them **identically** in pre-flight, verify-gate-2, Layer 7/8, and the final report. Shell state does not persist between the orchestrator's Bash calls, so do NOT rely on a `$SESSION_DIR` variable surviving across steps: re-derive the concrete absolute session-dir path (from `state.json.session_dir`) at the top of every bash block that writes an artifact, and `mkdir -p` it before the first write.

`<session-id>` = ISO date + branch name **with `/` replaced by `-`** (branch names like `refactor/fsd-auto-…` would otherwise nest directories), e.g. `2026-07-17-refactor-fsd-auto-2026-07-17`. If the dir already exists for the same date, append `-2`, `-3`, etc. Old session dirs are never deleted — `.refactor-report/` accumulates as a per-project history.

### Auto-gitignore (FIRST prefatory commit)

Before anything else writes to disk — before the knip install, before the smoke bootstrap, before the first baseline — the orchestrator MUST ensure `.refactor-report/` is ignored:

1. If `git check-ignore -q .refactor-report/` exits non-zero (not ignored), append `.refactor-report/` to `.gitignore` (with a leading blank line + comment `# dm812-frontend-fsd-refactor-loop session artifacts`).
2. Stage and commit the `.gitignore` change as the **first** prefatory commit of the session:
   ```
   chore: ignore .refactor-report/ (dm812-frontend-fsd-refactor-loop artifacts)
   ```
3. If `git check-ignore -q` reports it already covered (directly or via a parent pattern), skip silently.

Ordering matters: every later `git clean -fd` (rollback, bootstrap revert) relies on the session dir being ignored — `git clean` without `-x` never touches ignored paths, so `state.json` and all artifacts survive any revert.

## State file (resume support)

`state.json` shape:

```json
{
  "started_at": "ISO timestamp",
  "started_epoch": 1789000000,
  "mode": "attended|unattended",
  "branch": "refactor branch the run commits to",
  "base_branch": "branch the run started from",
  "project_dir": "absolute path",
  "session_dir": "absolute path to .refactor-report/<session-id>/",
  "pm": "npm|pnpm|yarn|bun",
  "flags": { "skip": [5, 6], "include": [], "time_budget_h": 6, "setup_smoke": false, "dry_run": false },
  "start_commit": "hash recorded AFTER all prefatory commits",
  "layer_start_commit": "hash at the start of the layer currently in_progress",
  "pre_bootstrap_commit": "hash before smoke bootstrap (null unless bootstrap ran)",
  "layers": {
    "0": "done|skipped|in_progress|failed",
    "1": "done|skipped|in_progress|failed"
  },
  "last_commit": "hash of last refactor commit",
  "baseline": { "build": "green", "lint_errors": 15, "lint_warnings": 1, "tests_pass": 92, "tests_fail": 11, "knip_lines": 61, "steiger_violations": 34 },
  "deferred": [],
  "failures": {},
  "bootstrap_failure": null,
  "smoke_decision": "available|bootstrap|skip-5-6|null"
}
```

At session start, stamp every layer planned for skipping (from `--skip` / the 5-6 default) as `"skipped"` immediately — not lazily when reached — so the resume rule below works even when a run halts early.

### Resume protocol (`--resume`)

Resuming is gated behind the explicit flag — without `--resume`, always create a fresh session (and require a clean tree).

On `--resume`:
1. Glob `.refactor-report/*/state.json`, pick the newest `started_at` whose layers are not all terminal (`done`/`skipped`/`failed`). If none qualify, report "nothing to resume" and stop. (The session-id embeds yesterday's date — never reconstruct the path from today's date.)
2. `git switch` to `state.json.branch` (never `-c`). Abort with a clear message if the branch is missing or HEAD has diverged from `state.json.last_commit`.
3. If the tree is dirty AND a layer is `in_progress` (a crashed run), do NOT abort: run the Rollback procedure for that layer first (`git reset --hard <layer_start_commit> && git clean -fd`), then re-run that layer.
4. Resume from the first layer whose status is `in_progress` or absent. `done`, `skipped`, and `failed` are terminal — never re-run them on resume.
5. Load baselines and effective flags from the resumed session's `state.json`. Never recapture baselines mid-refactor.
6. Combining `--resume --layer=N` runs only layer N inside the resumed session (the supported way to retry a `failed` layer); other layers' statuses are untouched.

## Layer order and scope

Standard FSD bottom-up. **Layers 5 and 6 are SKIPPED by default** — they run only on explicit opt-in (`--include=5,6`), and even then the Smoke gate section is the single decision point for whether they may execute.

| # | Layer | Risk | Default action |
|---|---|---|---|
| 0 | Tooling setup (pre-flight, prefatory commits, baselines) | None | Run (orchestrator-only, no subagents) |
| 1 | `src/shared/` | Low | Run |
| 2 | `src/entities/` | Low | Run |
| 3 | `src/features/` (dedup; demote single-page features per pages-first) | Medium | Run |
| 4 | `src/widgets/` (composites reused by ≥ 2 pages; demote single-use widgets) | Medium | Run |
| 5 | `src/pages/` (pages-first consolidation: absorb single-use slices; page-private decomposition) | High UI risk | Skip (opt-in via `--include`; see Smoke gate) |
| 6 | `src/app/` (providers, router, segments-only hygiene, `processes/` migration) | Medium | Skip (opt-in via `--include`; see Smoke gate) |
| 7 | Final cleanup pass (knip diff, net LOC, dead-export sweep) | Low | Run |
| 8 | Docs sync (regenerate codemaps + update CLAUDE.md) | Low | Run |

Layer 0 does not run the six-phase cycle — it is the pre-flight itself. Layer 8 has its own phases (see its section). The six-phase cycle below applies to Layers 1–7.

## Per-layer cycle (the core loop)

Each layer runs this six-phase cycle. Do NOT proceed to the next phase if the previous one fails.

### Model selection per step (dm812 tiering convention)

Worker subagents get an explicit lower tier; verification is **never** downgraded. "Session tier" means whatever model the main session runs — a relative top tier (Fable-safe), passed by *omitting* the `model` option, never by naming a model.

| Step | Role | Model | Why this tier |
|---|---|---|---|
| Layer 0 pre-flight, verify-gate-1, verify-gate-2, commits | orchestrator | session (no subagent) | Judgment + bookkeeping stay in the main loop |
| Phase 1 architect — Layers 1–4, 7 | reasoning worker | `sonnet` | Plans against explicit FSD canon with knip/steiger evidence; bounded scope |
| Phase 1 architect — Layers 5–6 | high-risk planner | session tier (omit `model`) | Pages/app touch routing, providers, live UI state; plan quality is the main defense, so no downgrade |
| Phase 3 refactor-cleaner | execution worker | `sonnet` | Executes an already-approved plan; no open-ended reasoning |
| Phase 4 gates (build/lint/test/knip/steiger) | deterministic tooling | none | No model involved |
| Phase 5 code-reviewer | verifier | session tier (omit `model`) | dm812 rule: verify roles are never downgraded |
| Layer 8 Phase A codemap generation | mechanical writer | `haiku` | Tree listings + export enumeration; format-following, cheap, high-volume |
| Layer 8 Phase B CLAUDE.md sync | synthesis worker | `sonnet` | Deciding what drifted requires judgment, not just formatting |

Never spawn a `haiku` worker for anything that edits source code — haiku is docs/enumeration only.

### Phase 1 — architect (read-only)

First record the layer's start commit: `state.json.layer_start_commit = $(git rev-parse HEAD)`, and set `state.json.layers[<N>] = "in_progress"`.

Spawn the architect subagent (`ecc:architect` here; any equivalent read-only architecture agent works) at the tier from the model table (`sonnet` for Layers 1–4/7; session tier for Layers 5–6) and a prompt that includes:
- The **FSD 2.1 canon section** of this skill, verbatim — plans must respect the import rule, public-API rules, and pages-first.
- The CLAUDE.md content of the project (so it respects realtime policy, denormalized columns, migration rules, theme tokens, i18n).
- The current FSD layer being analyzed.
- Knip baseline results scoped to this layer.
- Steiger findings scoped to this layer (from the latest `steiger-after-layer<M>.txt`, or `baseline-steiger.txt` for Layer 1) — each `fsd/*` violation in scope is either planned-for or explicitly deferred with a reason.
- Known dups to verify (carry-over from previous layer's deferred items, if any).
- Explicit instruction: "no code, output a markdown plan; rank by risk; flag per-layer abort criteria (risks that should stop this layer)."
- Deliverable contract: file moves/creates/deletes/edits with paths and rationale.

Save output to `architect-layer<N>.md`.

### Phase 2 — verify-gate-1 (orchestrator does this)

Read the architect's plan. Sanity checks before approving:
- No proposal to add new dependencies (unless the user pre-approved).
- No proposal to touch `supabase/`, `services/`, migrations, edge functions, or anything outside `src/`.
- No proposal to move domain types into `shared/` (FSD violation).
- No proposal that introduces an **upward or same-layer import** — the only sanctioned same-layer path is entities `@x` (`entities/A/@x/B`).
- No new `export *` wildcard re-exports in slice indexes; no new deep imports that bypass a slice's `index.ts` from outside the slice.
- No proposal to **extract** a feature/entity/widget consumed by a single page — pages-first says merge into the page instead; push back citing canon rule 6.
- No proposal to add slices to `app/` or `shared/` (segments only there), and nothing new under a deprecated `processes/`.
- No proposal to delete a file that grep finds is actually imported (re-grep yourself, do not trust the architect blindly).
- For "dead file" claims, run literal symbol greps to confirm.

If any check fails, push back with the concrete counter-evidence: via SendMessage if the architect agent is still addressable; if it has already finished, spawn a fresh architect with the original plan + your counter-evidence and request a revised plan. Do not proceed until the plan passes. Cap this loop at 2 push-back rounds: if the plan still fails, mark the layer `failed` in state.json (reason: "architect plan did not converge") and move to the next layer — never loop indefinitely on an unattended run.

### Phase 3 — refactor-cleaner (executes the plan)

Spawn the cleaner subagent (`ecc:refactor-cleaner`) with model `sonnet` and a prompt that includes:
- The full architect plan from `architect-layer<N>.md`.
- The verify-gate-1 corrections.
- The FSD 2.1 canon section (verbatim) + project rules (folder-per-component, English comments, no mutation, no new deps).
- Stopping rules ("if any single file is unclear, stop and report").
- Explicit do-not-commit instruction (orchestrator commits).

Save output to `cleaner-layer<N>.md`.

### Phase 4 — verify-gate-2 (the safety net)

Run from the project dir, using the detected package manager from `state.json.pm` (see the command matrix in Pre-flight — never hardcode npm):

```bash
<pm> run build
<pm> run lint          # or: <pm-exec> eslint src/  if there is no lint script
CI=true <pm> run test  # CI=true forces vitest/jest single-run, no watch mode
<pm-exec> knip --no-exit-code --reporter compact > <session-dir>/knip-after-layer<N>.txt
<pm-exec> steiger ./src > <session-dir>/steiger-after-layer<N>.txt 2>&1 || true   # steiger exits non-zero on violations — never let that kill the chain
```

Compare to baselines (`state.json.baseline` holds parsed integers):
- **Build**: must be green. Failure → revert layer (see Rollback).
- **Lint**: error count ≤ `baseline.lint_errors`. Improvement is fine; regression is not.
- **Tests**: pass count ≥ `baseline.tests_pass`; fail count ≤ `baseline.tests_fail`. New regression → revert. Exception: an intentional, plan-declared test consolidation (merged duplicates, updated hardcoded-path tests per the Layer 4 note) may lower the pass count — allowed only when the architect plan or cleaner report explicitly accounts for every removed/renamed test AND the fail count is still ≤ baseline; an unexplained pass-count drop is a gate failure. If the runner's summary cannot be parsed into numbers, treat the gate as UNKNOWN → halt; never wave it through.
- **Knip**: compare line count against the snapshot of the most recent successfully committed layer — `knip-after-layer<M>.txt` for the highest `M < N` with `layers[M] == "done"`, searching layers 1+ only (Layer 0 produces no knip-after snapshot); for Layer 1, or when no such committed layer exists, the anchor is `baseline-knip.txt`. Allowance: ≤ anchor + 10 lines (new helpers awaiting consumers are normal). On overage, investigate and classify the growth (awaiting-consumers vs accidental dead exports); only an **unexplained** overage counts as a gate failure. The Layer-0 baseline is kept solely for Layer 7's whole-run delta report.
- **Steiger**: count `fsd/` rule hits in the snapshot (`grep -c 'fsd/' <file>`, 0 on no match) and compare against the same anchor rule as knip (last committed layer's snapshot, else `baseline-steiger.txt`). Violations must be **≤ anchor — no allowance**: unlike knip, an architecture violation is never "awaiting a consumer"; a refactor layer must not introduce new FSD violations, and should usually reduce the count in its own layer's scope. Skip this gate entirely (and note it in SUMMARY.md) when `baseline.steiger_violations` is `null` — see the pre-flight fallback for a broken/unrunnable steiger.

Also run grep-checks the architect specified (e.g. "zero `STATUS_MAP` left in features/").

If any gate fails, attempt 1 round of self-fix (read errors, apply targeted edits, re-run gates). If still failing, **rollback** (see below).

### Phase 5 — code-reviewer (final quality gate)

Spawn the reviewer subagent (`ecc:code-reviewer`) at the **session-tier model** (verify roles are never downgraded) with the layer's git diff. Required output: severity-tagged findings + verdict (APPROVE / APPROVE WITH WARNINGS / BLOCK).

- BLOCK or CRITICAL → do not commit; fix and re-review (max 2 fix-and-re-review rounds — if still blocked, treat as a verify-gate-2 failure: rollback and mark the layer failed).
- HIGH → fix in this layer's commit before proceeding.
- MEDIUM → fix if quick (≤ 5 min); otherwise log to `state.json.deferred[]` for follow-up.
- LOW → log to deferred, do not block.

Any code change made during Phase 5 (including quick MEDIUM fixes) invalidates the Phase 4 result: re-run at minimum `<pm> run build` — preferably the full verify-gate-2 — before Phase 6. A new failure here is handled exactly like a Phase 4 failure.

Save output to `reviewer-layer<N>.md`.

### Phase 6 — commit

Stage **everything** the layer produced — `git add -A` — so intentional cross-layer files (e.g. Layer 3's helpers in `shared/`) land in the owning layer's commit and the post-commit invariant below is meaningful.

Conventional commit message:

```
refactor(<layer>): <one-line summary>

<3-6 line summary of what changed and why>

Verification: build clean, lint <count> (matches/improves baseline),
tests <pass>/<fail> (matches/improves baseline), knip <lines>.
```

Rules:
- Never `--amend`.
- Never `--no-verify`.
- Never push (orchestrator stays local).
- Use HEREDOC for multi-line messages.
- After the commit, `git status --porcelain` MUST be empty — if not, halt (see Stop conditions).
- Update `state.json.layers[<N>] = "done"` and `state.json.last_commit = <hash>`.

## Rollback

If verify-gate-2 fails after refactor-cleaner and self-fix can't rescue:

```bash
SD=<absolute session dir>   # inline the concrete path — shell vars never survive across the orchestrator's Bash calls
LSC=$(jq -r .layer_start_commit "$SD/state.json") \
  && git reset --hard "$LSC" \
  && git clean -fd \
  && git status --porcelain
```

Run this as ONE Bash call, `&&`-chained, so a failed reset aborts BEFORE clean runs (a fall-through `git clean` on an un-reset tree would delete untracked files while leaving the breakage in place). `reset --hard` clears worktree AND index (incl. staged `git mv` renames); `clean -fd` is repo-wide — ignored paths (`.refactor-report/`) survive because clean lacks `-x`. The final `git status --porcelain` MUST print nothing — if it does, HALT.

Do NOT use `git restore .` (it restores the worktree *from the index*, so staged `git mv` renames survive it) and do NOT scope the clean to the layer dir (layers legitimately create files in other layers — e.g. the features layer adds helpers under `shared/`; a scoped clean leaves those orphans to leak into the next layer's commit).

Mark `state.json.layers[<N>] = "failed"`, write reason to `state.json.failures[<N>]`, and proceed to next layer (do NOT halt the whole loop on a single layer failure unless three consecutive layers fail).

## Smoke gate (governs Layers 4–6; the single decision point for 5/6)

The smoke decision is made **once, at pre-flight**, and recorded as `state.json.smoke_decision`:

- `playwright.config.*` exists → `smoke_decision = "available"`. After layers 4, 5, 6 run:
  ```bash
  <pm-exec> playwright test --grep @smoke --reporter=line
  ```
  If the project has no `@smoke` marker, run only the lightest E2E. If smoke fails, treat as verify-gate-2 failure and rollback.
- No Playwright + `--setup-smoke` passed → run the "Smoke bootstrap" sub-flow during pre-flight (after the gitignore commit); `smoke_decision = "bootstrap"`.
- No Playwright + Layers 5/6 scheduled + **attended** → ask once, at pre-flight (never mid-run): "Playwright not found and Layers 5/6 are scheduled. Bootstrap a minimal smoke suite now? (y = bootstrap / n = skip Layers 5-6)". `n` means both: no bootstrap AND auto-skip 5/6.
- No Playwright + **unattended** → never ask: auto-skip Layers 5 and 6 (`smoke_decision = "skip-5-6"`), stamp them `"skipped"` in state.json, log the decision, and note it in SUMMARY.md ("Smoke not run — no Playwright in project").

If `smoke_decision` is not `available`/`bootstrap`, Layer 4 simply proceeds without a smoke check (verify-gate-2 alone still applies) — only Layers 5/6 are hard-gated on a smoke suite.

## Smoke bootstrap (when `--setup-smoke` or user opted in at pre-flight)

Runs ONCE per project during pre-flight, AFTER the `.gitignore` prefatory commit (so a failed-bootstrap revert can never destroy session artifacts). Idempotent — if Playwright is already installed, skip. First record and PERSIST the pre-bootstrap commit: `state.json.pre_bootstrap_commit = $(git rev-parse HEAD)` — Steps 2–5 are separate tool calls, so a shell variable would not survive to Step 6.

### Step 1 — install Playwright

Use the detected PM's add form (see command matrix): `npm install -D @playwright/test` / `pnpm add -D @playwright/test` / `yarn add -D @playwright/test` / `bun add -d @playwright/test`. Then:

```bash
<pm-exec> playwright install chromium   # browser binary only
```

Do NOT use `--with-deps` — it needs root/sudo and will hang on a password prompt or fail in an unattended run. If the later smoke run fails on missing system libraries, log it to `state.json.bootstrap_failure` and take the bootstrap-failure path below; never attempt sudo unattended.

### Step 2 — generate `playwright.config.ts`

Write to project root if absent. Defaults tuned for local + CI:

```ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  timeout: 30_000,
  expect: { timeout: 5_000 },
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: 'line',
  use: {
    baseURL: process.env.E2E_BASE_URL ?? 'http://localhost:5173',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: process.env.CI
    ? undefined
    : {
        command: '<pm> run dev', // substitute the DETECTED package manager, e.g. 'pnpm run dev'
        url: 'http://localhost:5173',
        reuseExistingServer: true,
        timeout: 60_000,
      },
});
```

If the project's dev server runs on a non-default port (read from `vite.config.*` or `package.json scripts.dev`), substitute the correct port. If unsure: attended → ask now (still pre-flight); unattended → default to 5173 (Vite) / 3000 (Next/CRA) based on detected framework.

### Step 3 — generate minimal `@smoke` suite

Write `tests/e2e/smoke.spec.ts`:

```ts
import { test, expect } from '@playwright/test';

test.describe('@smoke critical paths', () => {
  test('app shell loads without runtime error', async ({ page }) => {
    const errors: string[] = [];
    page.on('pageerror', (err) => errors.push(err.message));
    page.on('console', (msg) => {
      if (msg.type() === 'error') errors.push(msg.text());
    });

    await page.goto('/');
    await expect(page.locator('body')).toBeVisible();
    expect(errors, `console errors: ${errors.join('; ')}`).toHaveLength(0);
  });

  test('public route renders main landmark', async ({ page }) => {
    await page.goto('/');
    // role=main is required by the app shell; if absent, the page never hydrated
    await expect(page.getByRole('main').or(page.locator('#root > *'))).toBeVisible();
  });
});
```

For projects with auth, also generate `tests/e2e/smoke-auth.spec.ts` that visits the login route and asserts the form renders. Do NOT auto-generate authenticated flows — those need real credentials and are out of scope for bootstrap.

### Step 4 — wire npm script

Add to `package.json` if absent:

```json
{
  "scripts": {
    "test:e2e": "playwright test",
    "test:e2e:smoke": "playwright test --grep @smoke"
  }
}
```

### Step 5 — gitignore

Append to `.gitignore` (skip if already present):

```
# playwright (added by dm812-frontend-fsd-refactor-loop --setup-smoke)
/test-results/
/playwright-report/
/playwright/.cache/
```

### Step 6 — verify and commit

```bash
<pm> run test:e2e:smoke   # must be green before continuing
```

If the smoke run fails, treat the bootstrap as failed: revert all bootstrap changes with `git reset --hard "$(jq -r .pre_bootstrap_commit <session-dir>/state.json)" && git clean -fd` (session artifacts survive — the dir is already gitignored), log the failure to `state.json.bootstrap_failure`, and then: attended → ask whether to (a) retry with manual port/route hints, (b) proceed without smoke (auto-skip Layers 5-6), or (c) abort; unattended → take (b) automatically and log it.

If green, commit as the next prefatory commit (after the `.gitignore` commit — and after the tooling commit, when knip/steiger needed installing):

```
chore(test): bootstrap Playwright smoke suite (dm812-frontend-fsd-refactor-loop)

- Add @playwright/test, chromium binary, playwright.config.ts.
- Add tests/e2e/smoke.spec.ts covering app shell load + main landmark.
- Add npm scripts test:e2e and test:e2e:smoke.

Verification: smoke suite green against local dev server.
```

After bootstrap, the regular smoke gate (Layers 4/5/6) uses the just-created suite.

## Stop conditions for the entire loop

Halt the whole skill (do not proceed to the next layer) if:

1. **Clean-tree invariant violated**: immediately after every layer commit and after every rollback, `git status --porcelain` MUST be empty. If it isn't, halt and list the stray paths in HALT.md. (Mid-layer the tree is legitimately dirty — the invariant is only checked at these two checkpoints.)
2. Three consecutive layers rolled back.
3. Build is broken AND self-fix didn't restore it AND rollback didn't either.
4. Time budget exceeded (default 6 hours total; configurable via `--time-budget=Nh`). Mechanics: at each layer boundary (before Phase 1), run `date +%s` and compare against `state.json.started_epoch`; if elapsed > budget, finish nothing new — halt at the current clean commit.

On halt, write a final report to `<session-dir>/HALT.md` with: which layer halted, why, what to inspect manually, suggested resume command.

## Pre-flight (= Layer 0; run before any refactor layer)

Order matters. Steps 0–5 gather facts and ask ALL questions (attended mode); steps 6–8 make the prefatory commits; step 9 captures baselines.

**0. Run mode** — decide attended/unattended per the "Run mode" section (ask now if genuinely ambiguous); recorded into state.json at step 3.

**`--dry-run`:** run steps 0–5 only — NO prefatory commits, NO installs, NO baseline capture. Then for each in-scope layer (same `--skip`/`--include` resolution as a real run) run Phase 1 (architect) and save `architect-layer<N>.md`; stop there — no cleaner, no commits, repo left byte-identical (session dir aside). If knip/steiger aren't already installed, note in each plan that that input was unavailable (dry-run never installs).

**1. Repo state + branches**

```bash
[[ -z "$(git status --porcelain)" ]] || { echo "DIRTY TREE — abort"; exit 1; }   # skip this abort only in the --resume crashed-layer path
git rev-parse --abbrev-ref HEAD            # record as base_branch
```

Branch policy:
- `--resume` → switch to `state.json.branch` (never create); see Resume protocol.
- `--branch=<name>` → `git switch -c <name>`.
- Neither, and HEAD is the repo's default branch (via `git symbolic-ref refs/remotes/origin/HEAD`, falling back to main/master when no remote) or detached → automatically `git switch -c refactor/fsd-auto-$(date +%F)` (suffix `-2`, `-3` on collision). Never commit a refactor run directly onto the default branch — Layer 7's "let the user review the branch" depends on this. Abort with a clear message if branch creation fails.
- Neither, and HEAD is already a named non-default branch → work directly on it; no new branch is created.

Record `branch`, `base_branch` in state.json.

**2. Package manager detection**

```bash
PM=npm                                        # default when nothing (or too much) matches
n=0
[[ -f package-lock.json ]] && { PM=npm;  n=$((n+1)); }
[[ -f pnpm-lock.yaml    ]] && { PM=pnpm; n=$((n+1)); }
[[ -f yarn.lock         ]] && { PM=yarn; n=$((n+1)); }
[[ -f bun.lock || -f bun.lockb ]] && { PM=bun; n=$((n+1)); }   # bun ≥1.2 writes text bun.lock
[[ $n -gt 1 ]] && PM=npm                      # multiple lockfiles → npm, per pre-condition 4
echo "PM=$PM"
```

Record the result in `state.json.pm`. Shell variables do NOT survive across the orchestrator's Bash calls — in every later snippet, `<pm>` / `<pm-exec>` mean the **concrete inlined** command per this matrix:

| `state.json.pm` | run script `<pm> run X` | local bin `<pm-exec> X` | add dev dep |
|---|---|---|---|
| npm | `npm run X` | `npm exec --no -- X` | `npm install -D X` |
| pnpm | `pnpm run X` | `pnpm exec X` | `pnpm add -D X` |
| yarn | `yarn run X` | `yarn run X` | `yarn add -D X` |
| bun | `bun run X` | `bunx X` | `bun add -d X` |

(`yarn i` and `bun exec` do not do what you'd guess; `bun test` runs bun's own runner, not the package script — always use the `run` form.)

**3. Session dir + state.json**

Create `<project-root>/.refactor-report/<session-id>/` (`mkdir -p`), write initial `state.json` with `started_at`, `started_epoch` (`date +%s`), `mode`, `pm`, `flags`, `session_dir`; stamp planned-skip layers as `"skipped"` and set `layers["0"] = "in_progress"`. Layer 0 MUST get a terminal status (`"done"` after step 9) — otherwise `--resume` would treat it as "absent", re-target pre-flight, and recapture baselines mid-refactor.

**4. Smoke decision** — per the Smoke gate section (ask now if attended; auto-decide if unattended).

**5. Any remaining questions** (unknown build/lint/test scripts, non-FSD layout, dev-server port) — ask now or never.

**6. Prefatory commit 1 — gitignore** (see Auto-gitignore).

**7. Prefatory commit 2 — tooling install: knip + steiger (only those absent)**

Check presence PnP-safely — grep `package.json` `dependencies`/`devDependencies` for `"knip"`, `"steiger"`, and `"@feature-sliced/steiger-plugin"` (do not test `node_modules/`, which Yarn PnP doesn't have). Install whichever are absent with the PM's add form. If steiger was just installed and no `steiger.config.{ts,js,mjs}` exists, write a minimal one at project root:

```ts
import { defineConfig } from 'steiger'
import fsd from '@feature-sliced/steiger-plugin'

export default defineConfig([...fsd.configs.recommended])
```

Then **commit package.json + lockfile + config in one commit immediately**:

```
chore: add knip + steiger (dm812-frontend-fsd-refactor-loop tooling)
```

An uncommitted install would either trip the clean-tree invariant or be silently stripped by the first `git reset --hard` rollback. Steiger is beta software — if after install `<pm-exec> steiger ./src` crashes (as opposed to reporting violations), keep the commit, set `baseline.steiger_violations = null`, disable the steiger gate for the whole run, and log the reason to state.json + SUMMARY.md. Never halt the run over broken beta tooling; knip and the build/lint/test gates still stand.

**8. Prefatory commit 3 — smoke bootstrap** (only when opted in; see its section). After ALL prefatory commits: record `state.json.start_commit = $(git rev-parse HEAD)`. Layer 7 and the final report read this from state.json.

**9. Baselines** (into the session dir — never the repo root, which would dirty the tree):

```bash
SD=<absolute session dir>                      # inline the concrete path from state.json.session_dir
<pm> run build 2>&1 | tail -10  > "$SD/baseline-build.txt"
<pm> run lint  2>&1 | tail -5   > "$SD/baseline-lint.txt"    # or <pm-exec> eslint src/ if no lint script
CI=true <pm> run test 2>&1 | tail -20 > "$SD/baseline-tests.txt"
<pm-exec> knip --no-exit-code --reporter compact > "$SD/baseline-knip.txt"
<pm-exec> steiger ./src > "$SD/baseline-steiger.txt" 2>&1 || true
```

Then parse the captures into **integers** in `state.json.baseline`:
- Tests: vitest prints `Tests  N passed`-style summary, jest prints `Tests: N failed, M passed, K total`, node:test/TAP prints `# pass N` / `# fail N`. Parse whichever the project's runner emits into `tests_pass` / `tests_fail`.
- Lint: eslint prints `✖ N problems (E errors, W warnings)` → `lint_errors` / `lint_warnings`.
- Knip: `wc -l` of the compact report → `knip_lines`.
- Steiger: `grep -c 'fsd/' baseline-steiger.txt` (0 on no match) → `steiger_violations`. If the run crashed (see step 7), it's `null` and the steiger gate is disabled for the run — this is the ONE baseline allowed to be null.

If a summary cannot be parsed into numbers: attended → halt pre-flight and ask; unattended → halt with HALT.md. Never proceed with an empty baseline — verify-gate-2's comparisons would be silently vacuous for the whole run.

When step 9 completes, set `state.json.layers["0"] = "done"`.

## Layer-specific notes (lessons learned)

These are **carry-over wisdom from the polybet refactor** — bake them into the relevant layer's architect prompt.

### Layer 0 — tooling
- knip 6.x understands `entry`/`project` arrays. Add scripts/ and tests/ as entries or knip will flag them as dead.
- Don't enable knip's `--strict` initially; baseline noise will bury real findings.

### Layer 1 — shared
- Common dead code: unused UI primitives, legacy type files (`api.ts`, `legacy.ts`), unused constants in theme/.
- Segment hygiene (canon rule 3): `shared/` splits into purpose-named segments (`ui`, `api`, `lib`, `config`, `routes`, `i18n`). Essence-named dirs (`components/`, `hooks/`, `types/`, `utils/`) are rename/absorb targets — but only when the import-update fan-out is mechanical; otherwise log to deferred.
- Public API shape (canon rule 4): `shared/ui` and `shared/lib` get a **per-component index**, not one monolithic barrel — a monolithic `shared/ui/index.ts` defeats tree-shaking and is itself a refactor target.
- HIGH-VALUE: extract Supabase SELECT fragments into `shared/api/supabase/selects/*.ts` so consumer hooks share one string. Compose dependent fragments via template literals so they cannot drift (we learned this: build `MARKET_EVENT_JOIN` from `EVENT_SELECT`).
- BEWARE: if `shared/ui/<X>` imports from `@/features/*` or `@/entities/*`, that's an FSD violation (steiger: `fsd/forbidden-imports`). Replace with a structural local type (`Pick<...>`-style) inline.

### Layer 2 — entities
- Domain types belong here, NOT in shared.
- Status maps, status filters, effective-status rules → entity helpers.
- Generic helper signatures: `<Q>(query: Q, ...): Q` with single internal `as any` cast preserves caller type safety without coupling entities/ to PostgREST internals.
- DO NOT rename `MarketEvent → Event` (DOM type collision). DO NOT rename anything that overlaps with global identifiers without grepping first.
- Entity→entity references go through `@x` notation (canon rule 5): ad-hoc `entities/A → entities/B` imports become `entities/B/@x/A.ts` (a dedicated public API in B for A's use), imported as `entities/B/@x/A`. Keep these rare — if two entities are deeply entangled, consider whether they're really one slice.
- Business logic of entity *interactions* belongs in higher layers; an entity slice keeps `model`/`api`/`ui` for the concept itself.
- Cross-feature imports (`features/A → features/B`) are FSD violations; the fix is usually lifting the shared piece to entities/ — but only if it's truly domain, not a query envelope. (`@x` is sanctioned for entities only, not features.)

### Layer 3 — features
- Pages-first audit (canon rule 6): for every feature slice, count consuming pages. A feature used by exactly **one** page is a demotion candidate — merge it into that page. Do the merge in THIS layer only when it's a **pure move** (code unchanged, `git mv` into the page slice + import updates); if it requires reworking live page UI, log to `state.json.deferred[]` as Layer-5 scope instead. "Not everything needs to be a feature" — feature sprawl drowns out the features that matter.
- After Layer 1+2, biggest remaining wins are usually:
  - Mutation invalidation helpers (Promise.all blocks duplicated across 3+ setters).
  - Derivation cascades (e.g. effective limits, scope resolution) lifted to a `<feature>/cascade.ts`.
  - Missing-relation/error-code detection helpers in `shared/api/<x>/`.
  - Per-user realtime subscription helper in `shared/hooks/useUserScopedRealtime.ts` (3+ hooks usually duplicate this).
- DEFER: anything touching realtime channels/cache eviction in app providers — that belongs in Layer 6 (app).
- DEFER: edge-function wrappers with bespoke error mapping — they need parity tests before extraction.

### Layer 4 — widgets
- Move criteria (canon rules 6–7): promote to `widgets/` only what is reused by **≥ 2 pages** (or is a router-level block in nested routing). Page-private stays put — anticipated reuse doesn't count.
- Demotion audit: an existing widget consumed by exactly one page is not a widget — merge it back into that page (same pure-move rule as Layer 3; UI-rework merges go to deferred/Layer 5).
- Promote anonymous prop interfaces to `export interface XxxProps` in the same move.
- Watch for tests that hardcode component file paths (file-content / AST-string tests). Update those paths in the same commit, otherwise the test count regresses.
- Use `git mv` so git tracks rename, not delete+add. (Note: `git mv` STAGES the rename — this is why Rollback uses `git reset --hard`, not `git restore`.)

### Layer 5 — pages
- FSD 2.1 reframe: a fat page is NOT a smell (canon rule 6). The goal here is **consolidation and navigability**, not slimming: absorb the single-use features/widgets deferred from Layers 3–4, and decompose only where the team can't navigate the file.
- Decompose ONLY within the page slice's own `ui/` segment (page-private siblings; a legacy `components/` subfolder is acceptable if that's the project convention — don't churn it). Do NOT promote to widgets unless ≥ 2 pages would consume.
- Each fat-page split touches a lot of state — manual browser smoke is essential. If overnight, run Playwright smoke; if no Playwright, defer Layer 5 to a supervised session.
- Common splits in admin/manager pages: header / form / list / modal as siblings.

### Layer 6 — app
- AuthProvider/Router are load-bearing. Touch only with a clear win and only after Layers 1-4 are stable.
- `app/` has NO slices (canon rule 2) — segments only (`routes`, `store`, `styles`, `entrypoint`, providers). Reusable UI living in app/ is a violation (steiger: `fsd/no-ui-in-app`) — move it to widgets/ or shared/ui.
- If `src/processes/` exists (flagged at pre-flight), migrate its contents into `features/` and `app/` here; the layer is deprecated and must end this run empty or deleted.
- Realtime subscription audit goes here too (centralize the channel-name + cleanup pattern).

### Layer 7 — final pass
- Re-run knip, compare to the Layer-0 baseline (`baseline-knip.txt`), write delta to session report.
- Re-run steiger, compare to `baseline-steiger.txt`, write the violation delta (and the remaining `fsd/*` rule breakdown) to the session report — remaining violations become deferred items for the next session.
- Net LOC: `git diff "$(jq -r .start_commit <session-dir>/state.json)"..HEAD --stat | tail -1` — inline the concrete session-dir path (state.json does NOT live at the repo root), and always diff from `state.json.start_commit`, never a hardcoded `main..HEAD` (empty when the run is on main; wrong when the default branch is master).
- Generate a summary commit message tag (`refactor: complete FSD layer-by-layer pass — net -X LOC`).
- Do NOT push; let the user review the branch.

### Layer 8 — docs sync (codemaps + CLAUDE.md)

After all code-touching layers are committed, the project's docs almost certainly drifted (paths moved, new shared utilities, deleted legacy modules). This layer regenerates structural docs and re-anchors CLAUDE.md.

**Why this exists:** subagent runs (architect, code-reviewer) in future sessions need a quick architectural snapshot without grep'ing the whole repo. CLAUDE.md is the auto-loaded entry point; codemaps are the per-layer detail docs CLAUDE.md links to. Without this layer, the next session's agents work from a stale mental model and either over-grep or hallucinate structure.

**Pre-conditions:** Layers 1-7 complete (or at least all attempted layers committed). Working tree clean.

**Phase A — regenerate codemaps:**

1. Check whether the project has the `update-codemaps` skill available (here: `ecc:update-codemaps`). If yes, invoke it via the Skill tool. If no, generate codemaps via a `haiku` worker subagent (per the model table — mechanical tree/export enumeration, one subagent for all layers), giving it the exact per-file format below:
   - For each FSD layer dir under `src/` that exists, write `docs/CODEMAPS/<layer>.md` containing: layer purpose (1 line), folder tree (`tree -L 2 src/<layer>/` output), public exports per module (grep `export ` from `index.ts` files), notable cross-layer dependencies, and last-updated timestamp.
   - Layers to map by default: `shared`, `entities`, `features`, `widgets`, `pages`, `app`.
2. If `docs/CODEMAPS/` did not exist before, create it.
3. Save the raw output of the generator to `<session-dir>/codemaps-output.txt` for audit.

**Phase B — update CLAUDE.md:**

1. Check whether the project has the `update-docs` skill (here: `ecc:update-docs`). If yes, invoke it — it will refresh CLAUDE.md sections that drifted (commands, structure descriptions). If no, do a targeted sync via a `sonnet` worker (per the model table — drift detection needs judgment): re-read the FSD layer descriptions in CLAUDE.md against the current `src/` tree and fix any path/file references that no longer exist.
2. Ensure CLAUDE.md contains a `## Codemaps` section (create if missing) with explicit links:

   ```markdown
   ## Codemaps

   Per-layer structural maps. Read the relevant one before deep work in that layer.

   - [shared](docs/CODEMAPS/shared.md) — design system, api helpers, hooks, theme, i18n
   - [entities](docs/CODEMAPS/entities.md) — domain types and per-entity helpers
   - [features](docs/CODEMAPS/features.md) — user-facing behaviours and TanStack Query hooks
   - [widgets](docs/CODEMAPS/widgets.md) — composite blocks reused across pages
   - [pages](docs/CODEMAPS/pages.md) — route components grouped by role
   - [app](docs/CODEMAPS/app.md) — providers, router, layouts

   Regenerated by `/dm812-frontend-fsd-refactor-loop` Layer 8. Last sync: <ISO date>.
   ```

   Only list layers whose codemap files actually exist.
3. If CLAUDE.md already had a `## Codemaps` section, replace it in place (don't duplicate).

**Phase C — verify-gate (lighter than other layers):**

- `<pm> run build` must still be green (codemaps and CLAUDE.md are markdown, but a typo in a re-exported path during manual sync could break things — sanity check).
- Grep CLAUDE.md for the new codemap paths and `ls` each one to confirm the link targets exist.
- Lint/tests are not required to re-run (no source changes).

**Phase D — commit:**

```
docs: regenerate codemaps and sync CLAUDE.md after FSD refactor

- Regenerated docs/CODEMAPS/{shared,entities,features,widgets,pages,app}.md
  to reflect post-refactor structure.
- Updated CLAUDE.md with current paths and Codemaps section linking to the
  per-layer maps so future sessions can load architectural context cheaply.

Verification: build clean, all codemap links resolve.
```

After the commit, set `state.json.layers["8"] = "done"` and update `last_commit` (Layer 8 doesn't run the six-phase cycle, so Phase 6's bookkeeping never fires for it — without this, `--resume` sees Layer 8 as "absent" forever).

**Failure handling:** if `update-codemaps` / `update-docs` skills are not available AND manual generation would require > 30 min of synthesis, log to `state.json.deferred[]` as `"docs-sync: skill not installed, run manually"`, set `state.json.layers["8"] = "skipped"`, and skip Layer 8. Don't block the whole pipeline on missing tooling.

**Note on whether codemaps are needed at all:** they are most valuable for projects > 50 frontend files where CLAUDE.md alone can't carry the full structural picture, and where future sessions will spawn architect/reviewer subagents. For tiny projects with a comprehensive CLAUDE.md, codemaps add maintenance overhead with little payoff — in that case, prefer running only Phase B (CLAUDE.md re-sync) and skip Phase A. Use judgment: if `find src -type f | wc -l` < 50, default to Phase B only.

## Improvements baked in (vs the polybet first pass)

These are gaps we hit on polybet that this skill closes:

1. **Pre-flight baseline capture** — we discovered failing tests mid-flight; should have known up front.
2. **Per-layer rollback** — we manually fixed; should be automatic.
3. **State file for resume** — we lost time re-orienting between sessions.
4. **Stop on consecutive failures** — naive loops would push through breakage.
5. **Test files with hardcoded paths** — we hit this 3+ times (`marketsPolymarketFields.test.ts` had absolute paths and stale `ProbabilityGauge` assertions). The cleaner prompt now explicitly includes "scan tests for hardcoded paths and stale assertions before completing the layer".
6. **CLAUDE.md auto-load** — the architect prompt now includes the project CLAUDE.md so realtime policy, denormalized columns, migration rules are respected without prompting.
7. **Knip baseline diff per layer** — early detection if a layer accidentally creates dead exports.
8. **Smoke gate** — Playwright smoke between Layer 4-5-6 catches UI regressions agents can't see.
9. **Time budget** — bounded total runtime so it can't run for 12 hours unnoticed.
10. **Deferred-items log** — MEDIUM/LOW review findings are logged structured in state.json instead of buried in commit messages.
11. **Consistent commit format** — predictable messages for git log readability.
12. **Architect verify-gate** — second-guessing the architect's "dead code" claims with literal greps before deletion.

### Hardening pass (2026-07-17 audit)

A multi-agent adversarial audit confirmed and fixed 12 defects in the v1 text:

13. **Rollback rewritten** — `git reset --hard <layer_start_commit> && git clean -fd` (repo-wide): the old `git restore .` + layer-scoped clean left staged `git mv` renames and out-of-layer files to leak into the next commit. Stop-condition 1 is now a checkable porcelain-empty invariant at commit/rollback checkpoints.
14. **Truthful interaction model** — no more "60s timeout" or Ctrl+C graceful-stop fiction; explicit attended/unattended mode decided at pre-flight; ALL questions front-loaded to pre-flight.
15. **Runner-agnostic test baseline** — the old TAP-only grep produced an empty baseline on vitest/jest, making the test gate vacuous; now parses per-runner summaries into integers and halts if unparseable.
16. **Package-manager correctness end-to-end** — PM default + bun.lock detection + multiple-lockfile rule; per-PM command matrix (`yarn i` doesn't exist, `bun exec` ≠ bunx); PM recorded in state.json and inlined everywhere (verify-gate-2, webServer, Layer 8 used to hardcode npm).
17. **Gitignore commit reordered first** — the bootstrap-failure `git clean -fd` used to run while `.refactor-report/` was still un-ignored, destroying state.json.
18. **Resume protocol** — newest-non-terminal state.json discovery (date-based ids made yesterday's session invisible), flag persistence, skipped-stamping at start, crashed-layer recovery, `--branch` never re-created on resume.
19. **Auto-branch** — never commit onto the default branch; `refactor/fsd-auto-<date>` is created when no `--branch` is given.
20. **One authoritative Layer 5/6 rule** — skipped by default, opt-in via `--include=5,6`, Smoke gate is the single decision point (v1 contradicted itself in three places).
21. **Per-layer knip anchor** — gate compares against the last *committed* layer's snapshot, not the never-updated Layer-0 baseline (which accumulated legitimate growth into false failures).
22. **Canonical artifact names + session-dir writes** — baselines no longer land in the repo root (which dirtied the tree the skill itself requires clean); knip snapshots no longer vanish into /tmp.
23. **Knip install committed** — a prefatory commit, so the first rollback can't silently strip the devDependency.
24. **No `--with-deps`** — it requires sudo and hangs unattended runs.
25. **Second verification pass (same audit)** — rollback and bootstrap-revert read their commits from state.json instead of cross-call shell variables; Layers 0/8 get terminal statuses so `--resume` can't re-run pre-flight and recapture baselines; `--dry-run` is guaranteed zero-commit/zero-install; Phase 2/5 loops are bounded (2 rounds → fail the layer); any Phase-5 fix re-runs the build gate before commit; plan-declared test consolidation no longer false-fails the test gate.

### FSD 2.1 alignment pass (2026-07-17, official docs sync)

Re-checked against feature-sliced.design v2.1 + the Steiger repo:

26. **FSD 2.1 canon section** — the loop now carries the official rules (import rule, no-slices-in-app/shared, purpose-named segments, public API contract, `@x` notation, pages-first, widget reuse bar, deprecated `processes/`) and injects them verbatim into every architect and cleaner prompt.
27. **Pages-first turnaround** — v1 of this skill pushed code *up* the layers (Layer 4 promoted anything with ≥ 1 outside importer; Layer 5 decomposed fat pages). 2.1 says the opposite: extraction needs ≥ 2 consuming pages, single-use features/widgets get **demoted into their page** (pure moves in Layers 3–4, UI-rework merges deferred to Layer 5), and Layer 5 is reframed from "slim the pages" to "consolidate + navigability; fat pages are legitimate".
28. **Steiger regression gate** — the official FSD linter runs at baseline and after every layer; the gate allows no growth in `fsd/*` violations (unlike knip there's no +10 allowance — architecture violations are never "awaiting consumers"). Installed as part of the tooling prefatory commit with a minimal `steiger.config.ts`; beta-crash fallback sets the baseline to `null` and disables only this gate, never the run.
29. **Public-API enforcement in verify-gate-1** — plans are rejected if they introduce upward/same-layer imports (except entities `@x`), `export *` wildcards in slice indexes, deep imports bypassing an index, single-page extractions, or slices under `app/`/`shared/`.
30. **Per-step model table** — replaces the one-line tiering note: architect `sonnet` for Layers 1–4/7 but **session tier for high-risk Layers 5–6**; cleaner `sonnet`; reviewer session tier (never downgraded); Layer 8 codemaps `haiku` (docs only — haiku never edits source), CLAUDE.md sync `sonnet`. Session tier is always expressed by omitting `model`, never by naming one.

## Help mode (--help / -h / "помощь" / "как пользоваться")

If the invocation contains `--help`, `-h`, or the user asks "как пользоваться", "что умеет", "помощь", "usage", "what does this do" — DO NOT start the loop. Instead print the help block below and stop. The user is asking for documentation, not action.

Help block (print verbatim, then stop the skill):

```
/dm812-frontend-fsd-refactor-loop — overnight FSD layer-by-layer refactor

ЧТО ДЕЛАЕТ
  Прогоняет фронтенд через слои FSD (shared → entities → features →
  widgets → pages → app → final → docs-sync) с циклом architect →
  refactor-cleaner → code-reviewer → commit между verify-gates.
  Следует FSD 2.1: pages-first (слайс, который использует одна
  страница, вливается в неё, а не наоборот), public API / @x-нотация,
  сегменты по назначению. Steiger (официальный FSD-линтер) гоняется
  как regression-gate после каждого слоя вместе с knip.
  Layer 8 пересобирает codemaps и синхронизирует CLAUDE.md с новой
  структурой. Безопасно для запуска на ночь: все вопросы задаются
  ДО старта (pre-flight), посреди прогона скилл не спрашивает ничего.

ПРЕДУСЛОВИЯ
  • git-репо, чистый working tree (git status пустой)
  • src/ имеет FSD-разметку (или layered-эквивалент)
  • package.json с build/lint/test скриптами
  • запуск из корня репо

ОПЦИИ
  --skip=<layers>        Пропустить слои (csv). Layer 5/6 пропускаются
                         ПО УМОЛЧАНИЮ — их не нужно указывать.
  --include=<layers>     Включить слои обратно (csv), напр. --include=5,6.
                         Layer 5/6 всё равно требуют реального smoke-suite
                         (существующий Playwright или --setup-smoke);
                         attended-режим лишь позволяет задать вопрос
                         про bootstrap на pre-flight.
  --layer=<N>            Прогнать ТОЛЬКО один слой (0..8). Без --resume
                         всегда сначала выполняется pre-flight (новая
                         сессия); с --resume берутся baselines существующей.
                         Layer 8 = docs-sync (codemaps + CLAUDE.md).
  --resume               Продолжить незавершённую сессию: находит свежий
                         state.json в .refactor-report/*/, переключается
                         на её ветку, откатывает упавший in_progress-слой
                         и продолжает. Baselines НЕ пересобираются.
  --time-budget=<Nh>     Жёсткий лимит времени (default 6h). Проверяется
                         по date +%s на границе каждого слоя;
                         останавливается на чистом коммите.
  --branch=<name>        Создать и работать на этой ветке. Если флага нет
                         и HEAD на дефолтной ветке (main/master) — ветка
                         refactor/fsd-auto-<дата> создаётся автоматически:
                         скилл НИКОГДА не коммитит в main напрямую.
  --unattended           Ночной режим: ни одного вопроса после pre-flight,
                         все развилки решаются безопасным дефолтом
                         (без Playwright → Layer 5/6 auto-skip).
  --setup-smoke          Если в проекте нет Playwright — установить его
                         и сгенерировать минимальный @smoke-набор
                         (app shell + main landmark + login form, если
                         есть auth) на pre-flight. Отдельный коммит
                         chore(test): bootstrap. После этого Layer 5/6
                         (при --include=5,6) идут с реальным smoke-gate'ом.
  --dry-run              Только pre-flight + architect-планы по всем слоям,
                         без правок и коммитов.
  --help, -h             Показать это сообщение и выйти.

ТИПИЧНЫЕ СЦЕНАРИИ
  /dm812-frontend-fsd-refactor-loop --unattended --time-budget=6h
      → безопасный overnight: layers 0-4 + 7-8. Утром получишь SUMMARY.md.

  /dm812-frontend-fsd-refactor-loop --resume
      → продолжить вчерашнюю прерванную сессию.

  /dm812-frontend-fsd-refactor-loop --layer=3
      → только features/, surgical-блок (dedup helpers, query keys).

  /dm812-frontend-fsd-refactor-loop --include=5,6 --setup-smoke
      → полный проход, включая pages/app под реальным smoke-gate'ом.
        Запускай днём или после проверки smoke-набора.

  /dm812-frontend-fsd-refactor-loop --branch=refactor/auto-2026-07-17
      → работать на явно названной ветке.

  /dm812-frontend-fsd-refactor-loop --dry-run
      → только планы от architect по всем слоям, ноль правок.

АРТЕФАКТЫ
  Сессия пишет в КОРЕНЬ ПРОЕКТА (легко открыть в IDE):
    <project-root>/.refactor-report/<session-id>/
      ├── state.json              (для --resume)
      ├── baseline-{build,lint,tests,knip}.txt
      ├── architect-layer<N>.md   (план каждого слоя)
      ├── cleaner-layer<N>.md     (отчёт refactor-cleaner)
      ├── reviewer-layer<N>.md    (отчёт code-reviewer)
      ├── knip-after-layer<N>.txt
      ├── codemaps-output.txt     (Layer 8)
      ├── HALT.md                 (только при аварийной остановке)
      └── SUMMARY.md              (читай первым утром)

  .refactor-report/ добавляется в .gitignore ПЕРВЫМ отдельным коммитом
  любой сессии — до bootstrap'а и до baselines — чтобы артефакты
  не попадали в PR и переживали любой git clean.

КАК ОСТАНОВИТЬ
  • Ctrl+C убивает выполнение НЕМЕДЛЕННО — текущий слой может остаться
    незакоммиченным. Закоммиченные слои в безопасности. Следующий
    --resume сначала откатит незавершённый слой, потом продолжит с него.
  • Скилл сам остановится при: 3 подряд failed-слоях, нарушении
    инварианта чистого дерева после коммита/отката, сломанном build'е,
    который не спасли ни self-fix, ни rollback, или превышении
    --time-budget.

ЧТО НЕ ДЕЛАЕТ (намеренно)
  • Не пушит ничего на remote — только локальные коммиты.
  • Не коммитит в дефолтную ветку: без --branch на main/master
    автоматически создаётся refactor/fsd-auto-<дата>.
  • Не трогает supabase/, services/, миграции, edge-функции.
  • Не изменяет package.json deps кроме knip + steiger (и
    @playwright/test + chromium при --setup-smoke); каждая
    установка — отдельный коммит.
  • Не раздувает слои "на вырост": извлечение в features/widgets
    только при реальном переиспользовании ≥ 2 страницами (FSD 2.1).
  • Не amend'ит и не --no-verify.
  • Не задаёт вопросов посреди прогона — только на pre-flight.
  • Layer 5 (pages) и 6 (app) выключены по умолчанию: они трогают
    UI-state и требуют браузерной проверки. Включай --include=5,6
    только при наличии smoke-suite (Playwright или --setup-smoke).

УТРОМ
  Открой <project-root>/.refactor-report/<session-id>/SUMMARY.md —
  там список коммитов, метрики, deferred items для следующей сессии.
```

После печати help-блока — STOP. Не запускай pre-flight, не трогай файлы.

## Invocation

The orchestrator (you, Claude Code main session) reads this skill and runs the loop. Suggested invocation form from the user side:

```
/dm812-frontend-fsd-refactor-loop                          # default: layers 0-4 + 7-8 (5/6 skipped), 6h budget, auto-branch
/dm812-frontend-fsd-refactor-loop --include=5,6 --setup-smoke   # full pass incl. pages/app behind a real smoke gate
/dm812-frontend-fsd-refactor-loop --resume                 # continue interrupted session
/dm812-frontend-fsd-refactor-loop --layer=3                # single layer only — always runs pre-flight first unless combined with --resume
/dm812-frontend-fsd-refactor-loop --time-budget=4h         # bound total time
/dm812-frontend-fsd-refactor-loop --branch=refactor/auto   # explicit branch name
/dm812-frontend-fsd-refactor-loop --unattended             # overnight: zero mid-run questions
/dm812-frontend-fsd-refactor-loop --dry-run                # pre-flight + architect plans only, no edits/commits
```

If the user did not specify args, default to `--skip=5,6 --time-budget=6h` (safe overnight) plus the auto-branch rule from pre-flight step 1.

## Final report

At end of run (success or halt) write `<session-dir>/SUMMARY.md` with:
- Layers completed / skipped / failed.
- Commits produced (hashes + one-line each).
- Build/lint/test/knip/steiger delta vs baseline (steiger: violation count + remaining `fsd/*` rule breakdown, or "gate disabled — steiger unrunnable" when baseline was null).
- Net LOC delta (`git diff <state.json.start_commit>..HEAD --stat`).
- Smoke decision taken at pre-flight (and, if 5/6 were auto-skipped, why).
- Deferred items (review findings worth a follow-up session).
- Suggested next session: which deferred items to tackle first.
- Codemaps regenerated: yes/no, list of files written to `docs/CODEMAPS/`.
- CLAUDE.md sync status: refreshed paths + Codemaps section verified.

Echo the SUMMARY.md path to the user as the last action so they wake up to a single readable digest, not 200 lines of tool output.
