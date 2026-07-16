---
name: dm812-fsd-refactor-loop
description: Autonomous overnight refactoring of an FSD (Feature-Sliced Design) frontend, layer by layer, from shared/ up through app/. Combines architect → refactor-cleaner → code-reviewer agents with verify-gates between layers. Safe to launch unattended. Use when the user wants senior-level code quality, dedup, single-source-of-truth, dead-code removal across the whole frontend.
origin: personal-dm812
---

# dm812-fsd-refactor-loop

Multi-layer FSD refactor orchestration. Encodes the layer-by-layer flow we used on polybet (commits 5ffebef → fd8f1a6) plus safeguards we wished we had on the first pass.

## When to invoke

User asks for: "refactor whole frontend", "clean up codebase", "make it look like a senior wrote it", "run overnight", "dedup everywhere", or names this skill explicitly.

Pre-conditions you MUST check before starting:
1. Repo is a git repo with a clean working tree (`git status --porcelain` empty).
2. Project follows FSD or a layered architecture with these or equivalent dirs: `src/{app,pages,widgets,features,entities,shared}/`. If layout differs, ask the user to confirm the layer order before starting.
3. Build/lint/test commands are known (read `package.json` `scripts`). If you can't tell, ask once before starting.
4. There is a recognised package manager (npm/pnpm/yarn/bun). Default to `npm` if multiple lockfiles or unclear.

## Output location for artifacts

Artifacts live **inside the project repo** so they're easy to browse in the IDE alongside the diff. Create:

```
<project-root>/.refactor-report/<session-id>/
  knip-baseline.txt
  knip-after-layer<N>.txt
  lint-baseline.txt
  test-baseline.txt
  architect-layer<N>.md
  cleaner-layer<N>.md
  reviewer-layer<N>.md
  state.json                 # current layer + status (for resume)
  SUMMARY.md                 # final digest (written at end of run)
```

`<session-id>` = ISO date + branch name, e.g. `2026-05-11-main`. If the dir already exists for the same date, append `-2`, `-3`, etc. Old session dirs are never deleted — `.refactor-report/` accumulates as a per-project history.

### Auto-gitignore

On the very first artifact write of any session, the orchestrator MUST ensure `.refactor-report/` is ignored:

1. If `.gitignore` does not contain a line matching exactly `.refactor-report/` or `.refactor-report`, append `.refactor-report/` (with a leading blank line + comment `# dm812-fsd-refactor-loop session artifacts`).
2. Stage and commit the `.gitignore` change as a separate, prefatory commit before Layer 0 baselines run:
   ```
   chore: ignore .refactor-report/ (dm812-fsd-refactor-loop artifacts)
   ```
3. If `.gitignore` already covers it (directly or via a parent pattern), skip silently.

This keeps the artifacts visible locally without ever leaking into PRs or `git status` noise during the loop.

## State file (resume support)

`state.json` shape:

```json
{
  "started_at": "ISO timestamp",
  "branch": "main or refactor branch name",
  "project_dir": "absolute path",
  "layers": {
    "0": "done|skipped|in_progress|failed",
    "1": "done|skipped|in_progress|failed",
    ...
  },
  "last_commit": "hash of last refactor commit",
  "baseline": { "build": "green", "lint": "15e/1w", "tests": "92/11", "knip_lines": 61 }
}
```

On invocation: if `state.json` exists for an unfinished session of the same project, resume from the first non-`done` layer. Otherwise create fresh state.

## Layer order and scope

Standard FSD bottom-up. Skip nothing by default; user may pass `--skip=5,6` to skip riskier layers.

| # | Layer | Risk | Default action |
|---|---|---|---|
| 0 | Tooling setup (knip + baselines) | None | Run |
| 1 | `src/shared/` | Low | Run |
| 2 | `src/entities/` | Low | Run |
| 3 | `src/features/` (surgical subset) | Medium | Run |
| 4 | `src/widgets/` (lift reused composites from pages) | Medium | Run |
| 5 | `src/pages/` (decompose fat pages, page-private only) | High UI risk | Run with browser smoke gate; if no smoke runner available, ASK before starting |
| 6 | `src/app/` (providers, router) | Medium | Run |
| 7 | Final cleanup pass (knip diff, net LOC, dead-export sweep) | Low | Run |
| 8 | Docs sync (regenerate codemaps + update CLAUDE.md) | Low | Run |

Layers 5 and 6 should be opt-out by the user when launching for unattended overnight runs unless a Playwright smoke harness is wired (see "Smoke gate" section).

## Per-layer cycle (the core loop)

Each layer runs this 5-phase cycle. Do NOT proceed to the next phase if the previous one fails.

### Phase 1 — architect (read-only)

Spawn `architect` subagent with a prompt that includes:
- The CLAUDE.md content of the project (so it respects realtime policy, denormalized columns, migration rules, theme tokens, i18n).
- The current FSD layer being analyzed.
- Knip baseline results scoped to this layer.
- Known dups to verify (carry-over from previous layer's deferred items, if any).
- Explicit instruction: "no code, output a markdown plan; rank by risk; flag stop conditions."
- Deliverable contract: file moves/creates/deletes/edits with paths and rationale.

Save output to `architect-layer<N>.md`.

### Phase 2 — verify-gate-1 (orchestrator does this)

Read the architect's plan. Sanity checks before approving:
- No proposal to add new dependencies (unless the user pre-approved).
- No proposal to touch `supabase/`, `services/`, migrations, edge functions, or anything outside `src/`.
- No proposal to move domain types into `shared/` (FSD violation).
- No proposal to delete a file that grep finds is actually imported (re-grep yourself, do not trust the architect blindly).
- For "dead file" claims, run literal symbol greps to confirm.

If any check fails, push back to architect via SendMessage with the concrete counter-evidence; do not proceed until the plan passes.

### Phase 3 — refactor-cleaner (executes the plan)

Spawn `refactor-cleaner` with a prompt that includes:
- The full architect plan from `architect-layer<N>.md`.
- The verify-gate-1 corrections.
- Project rules (FSD, folder-per-component, English comments, no mutation, no new deps).
- Stopping rules ("if any single file is unclear, stop and report").
- Explicit do-not-commit instruction (orchestrator commits).

Save output to `cleaner-layer<N>.md`.

### Phase 4 — verify-gate-2 (the safety net)

Run from the project dir:

```bash
npm run build
npx eslint src/                                  # adjust to project's lint command
npm test                                         # adjust to project's test command
npx knip --no-exit-code --reporter compact > /tmp/knip-after.txt
```

Compare to baselines:
- **Build**: must be green. Failure → revert layer (see Rollback).
- **Lint**: ≤ baseline error count. Improvement is fine; regression is not.
- **Tests**: pass count ≥ baseline; fail count ≤ baseline. New regression → revert.
- **Knip**: line count ≤ baseline + 10 (new helpers awaiting consumers are normal). Bigger growth → investigate before commit.

Also run grep-checks the architect specified (e.g. "zero `STATUS_MAP` left in features/").

If any gate fails, attempt 1 round of self-fix (read errors, apply targeted edits, re-run gates). If still failing, **rollback** (see below).

### Phase 5 — code-reviewer (final quality gate)

Spawn `code-reviewer` with the layer's git diff. Required output: severity-tagged findings + verdict (APPROVE / APPROVE WITH WARNINGS / BLOCK).

- BLOCK or CRITICAL → do not commit; fix and re-review.
- HIGH → fix in this layer's commit before proceeding.
- MEDIUM → fix if quick (≤ 5 min); otherwise log to `state.json.deferred[]` for follow-up.
- LOW → log to deferred, do not block.

Save output to `reviewer-layer<N>.md`.

### Phase 6 — commit

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
- Update `state.json.layers[<N>] = "done"` and `state.json.last_commit = <hash>`.

## Rollback

If verify-gate-2 fails after refactor-cleaner and self-fix can't rescue:

```bash
git restore .                  # restore tracked files
git clean -fd src/<layer>/     # remove untracked files in the layer dir
```

Mark `state.json.layers[<N>] = "failed"`, write reason to `state.json.failures[<N>]`, and proceed to next layer (do NOT halt the whole loop on a single layer failure unless three consecutive layers fail).

## Smoke gate (optional, recommended for layers 4-6)

If `playwright.config.*` exists in the project, after layers 4, 5, 6 run a smoke suite:

```bash
npx playwright test --grep @smoke --reporter=line
```

If the project has no smoke marker, run only the lightest E2E. If smoke fails, treat as verify-gate-2 failure and rollback.

If no Playwright is configured, behavior depends on flags:
- **`--setup-smoke` passed**: run the "Smoke bootstrap" sub-flow below before Layer 0 baselines.
- **Interactive run + Layer 5 or 6 scheduled**: pause and ASK the user once: "Playwright not found. Bootstrap a minimal smoke suite now? (y/n/skip-layers-5-6)". Default to `n` after 60s if no reply (overnight-safe).
- **No flag, non-interactive**: skip smoke and document in commit message ("Smoke not run — no Playwright in project"). Layers 5 and 6 are auto-skipped in this case regardless of `--skip` value.

## Smoke bootstrap (when `--setup-smoke` or user opted in)

Runs ONCE per project before Layer 0. Idempotent — if Playwright is already installed, skip.

### Step 1 — install Playwright

```bash
$PM i -D @playwright/test                    # PM = npm/pnpm/yarn/bun (detected in pre-flight)
npx playwright install chromium --with-deps  # browser binary only; full install on demand
```

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
        command: 'npm run dev',
        url: 'http://localhost:5173',
        reuseExistingServer: true,
        timeout: 60_000,
      },
});
```

If the project's dev server runs on a non-default port (read from `vite.config.*` or `package.json scripts.dev`), substitute the correct port. If unsure, ASK once during interactive runs; in non-interactive runs, default to 5173 (Vite) / 3000 (Next/CRA) based on detected framework.

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
# playwright (added by dm812-fsd-refactor-loop --setup-smoke)
/test-results/
/playwright-report/
/playwright/.cache/
```

### Step 6 — verify and commit

```bash
$PM run test:e2e:smoke   # must be green before continuing
```

If smoke run fails, treat the bootstrap as failed: revert all bootstrap changes (`git restore . && git clean -fd`), log the failure to `state.json.bootstrap_failure`, and ask the user whether to (a) retry with manual port/route hints, (b) proceed without smoke (auto-skip Layers 5-6), or (c) abort.

If green, commit as a separate prefatory commit BEFORE the `.gitignore` artifact-ignore commit:

```
chore(test): bootstrap Playwright smoke suite (dm812-fsd-refactor-loop)

- Add @playwright/test, chromium binary, playwright.config.ts.
- Add tests/e2e/smoke.spec.ts covering app shell load + main landmark.
- Add npm scripts test:e2e and test:e2e:smoke.

Verification: smoke suite green against local dev server.
```

After bootstrap, the regular smoke gate (Layers 4/5/6) uses the just-created suite.

## Stop conditions for the entire loop

Halt the whole skill (do not proceed to the next layer) if:

1. `git status` becomes dirty in a way the orchestrator did not produce (someone else pushed a commit, or a hook modified files).
2. Three consecutive layers rolled back.
3. Build is broken AND self-fix didn't restore it AND rollback didn't either.
4. The user pressed Ctrl+C (interactive runs only).
5. Time budget exceeded (default 6 hours total; configurable via `--time-budget=Nh`).

On halt, write a final report to `<project-root>/.refactor-report/<session-id>/HALT.md` with: which layer halted, why, what to inspect manually, suggested resume command.

## Pre-flight (run before any layer)

```bash
# 1. Confirm repo state
[[ -z "$(git status --porcelain)" ]] || { echo "DIRTY TREE — abort"; exit 1; }
git rev-parse --abbrev-ref HEAD            # record branch

# 2. Confirm package manager
[[ -f package-lock.json ]] && PM=npm
[[ -f pnpm-lock.yaml ]] && PM=pnpm
[[ -f yarn.lock ]] && PM=yarn
[[ -f bun.lockb ]] && PM=bun

# 3. Install knip if absent
$PM ls knip > /dev/null 2>&1 || $PM i -D knip

# 4. Snapshot baselines
$PM run build 2>&1 | tail -10 > baseline-build.txt
npx eslint src/ 2>&1 | tail -3 > baseline-lint.txt
$PM test 2>&1 | grep -E "^# (fail|tests|pass)" > baseline-tests.txt
npx knip --no-exit-code --reporter compact > baseline-knip.txt
```

Persist all four baselines to the session dir.

## Layer-specific notes (lessons learned)

These are **carry-over wisdom from the polybet refactor** — bake them into the relevant layer's architect prompt.

### Layer 0 — tooling
- knip 6.x understands `entry`/`project` arrays. Add scripts/ and tests/ as entries or knip will flag them as dead.
- Don't enable knip's `--strict` initially; baseline noise will bury real findings.

### Layer 1 — shared
- Common dead code: unused UI primitives, legacy type files (`api.ts`, `legacy.ts`), unused constants in theme/.
- HIGH-VALUE: extract Supabase SELECT fragments into `shared/api/supabase/selects/*.ts` so consumer hooks share one string. Compose dependent fragments via template literals so they cannot drift (we learned this: build `MARKET_EVENT_JOIN` from `EVENT_SELECT`).
- BEWARE: if `shared/ui/<X>` imports from `@/features/*` or `@/entities/*`, that's an FSD violation. Replace with a structural local type (`Pick<...>`-style) inline.

### Layer 2 — entities
- Domain types belong here, NOT in shared.
- Status maps, status filters, effective-status rules → entity helpers.
- Generic helper signatures: `<Q>(query: Q, ...): Q` with single internal `as any` cast preserves caller type safety without coupling entities/ to PostgREST internals.
- DO NOT rename `MarketEvent → Event` (DOM type collision). DO NOT rename anything that overlaps with global identifiers without grepping first.
- Cross-feature imports (`features/A → features/B`) are FSD violations; the fix is usually lifting the shared piece to entities/ — but only if it's truly domain, not a query envelope.

### Layer 3 — features
- After Layer 1+2, biggest remaining wins are usually:
  - Mutation invalidation helpers (Promise.all blocks duplicated across 3+ setters).
  - Derivation cascades (e.g. effective limits, scope resolution) lifted to a `<feature>/cascade.ts`.
  - Missing-relation/error-code detection helpers in `shared/api/<x>/`.
  - Per-user realtime subscription helper in `shared/hooks/useUserScopedRealtime.ts` (3+ hooks usually duplicate this).
- DEFER: anything touching realtime channels/cache eviction in app providers — that belongs in Layer 6 (app).
- DEFER: edge-function wrappers with bespoke error mapping — they need parity tests before extraction.

### Layer 4 — widgets
- Move criteria: ≥ 1 importer outside the owning page. Page-private stays put.
- Promote anonymous prop interfaces to `export interface XxxProps` in the same move.
- Watch for tests that hardcode component file paths (file-content / AST-string tests). Update those paths in the same commit, otherwise the test count regresses.
- Use `git mv` so git tracks rename, not delete+add.

### Layer 5 — pages
- Decompose ONLY into the page's own `components/` subfolder. Do NOT promote to widgets unless ≥ 2 pages would consume.
- Each fat-page split touches a lot of state — manual browser smoke is essential. If overnight, run Playwright smoke; if no Playwright, defer Layer 5 to a supervised session.
- Common splits in admin/manager pages: header / form / list / modal as siblings.

### Layer 6 — app
- AuthProvider/Router are load-bearing. Touch only with a clear win and only after Layers 1-4 are stable.
- Realtime subscription audit goes here too (centralize the channel-name + cleanup pattern).

### Layer 7 — final pass
- Re-run knip, compare to layer-0 baseline, write delta to session report.
- Run `git diff main..HEAD --stat | tail -1` for net LOC.
- Generate a summary commit message tag (`refactor: complete FSD layer-by-layer pass — net -X LOC`).
- Do NOT push; let the user review the branch.

### Layer 8 — docs sync (codemaps + CLAUDE.md)

After all code-touching layers are committed, the project's docs almost certainly drifted (paths moved, new shared utilities, deleted legacy modules). This layer regenerates structural docs and re-anchors CLAUDE.md.

**Why this exists:** subagent runs (architect, code-reviewer) in future sessions need a quick architectural snapshot without grep'ing the whole repo. CLAUDE.md is the auto-loaded entry point; codemaps are the per-layer detail docs CLAUDE.md links to. Without this layer, the next session's agents work from a stale mental model and either over-grep or hallucinate structure.

**Pre-conditions:** Layers 1-7 complete (or at least all attempted layers committed). Working tree clean.

**Phase A — regenerate codemaps:**

1. Check whether the project has the `update-codemaps` skill available. If yes, invoke `Skill(update-codemaps)` (or run `/update-codemaps` if it's exposed as a slash command). If no, generate codemaps manually:
   - For each FSD layer dir under `src/` that exists, write `docs/CODEMAPS/<layer>.md` containing: layer purpose (1 line), folder tree (`tree -L 2 src/<layer>/` output), public exports per module (grep `export ` from `index.ts` files), notable cross-layer dependencies, and last-updated timestamp.
   - Layers to map by default: `shared`, `entities`, `features`, `widgets`, `pages`, `app`.
2. If `docs/CODEMAPS/` did not exist before, create it.
3. Save the raw output of the generator to `<session-dir>/codemaps-output.txt` for audit.

**Phase B — update CLAUDE.md:**

1. Check whether the project has the `update-docs` skill / `/update-docs` slash command. If yes, invoke it — it will refresh CLAUDE.md sections that drifted (commands, structure descriptions). If no, do a targeted manual sync: re-read the FSD layer descriptions in CLAUDE.md against the current `src/` tree and fix any path/file references that no longer exist.
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

   Regenerated by `/dm812-fsd-refactor-loop` Layer 8. Last sync: <ISO date>.
   ```

   Only list layers whose codemap files actually exist.
3. If CLAUDE.md already had a `## Codemaps` section, replace it in place (don't duplicate).

**Phase C — verify-gate (lighter than other layers):**

- `npm run build` must still be green (codemaps and CLAUDE.md are markdown, but a typo in a re-exported path during manual sync could break things — sanity check).
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

**Failure handling:** if `update-codemaps` / `update-docs` skills are not available AND manual generation would require > 30 min of synthesis, log to `state.json.deferred[]` as `"docs-sync: skill not installed, run manually"` and skip Layer 8. Don't block the whole pipeline on missing tooling.

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

## Help mode (--help / -h / "помощь" / "как пользоваться")

If the invocation contains `--help`, `-h`, or the user asks "как пользоваться", "что умеет", "помощь", "usage", "what does this do" — DO NOT start the loop. Instead print the help block below and stop. The user is asking for documentation, not action.

Help block (print verbatim, then stop the skill):

```
/dm812-fsd-refactor-loop — overnight FSD layer-by-layer refactor

ЧТО ДЕЛАЕТ
  Прогоняет фронтенд через 8 слоёв FSD (shared → entities → features →
  widgets → pages → app → final → docs-sync) с циклом architect →
  refactor-cleaner → code-reviewer → commit между verify-gates.
  Layer 8 пересобирает codemaps и синхронизирует CLAUDE.md с новой
  структурой. Безопасно для запуска на ночь.

ПРЕДУСЛОВИЯ
  • git-репо, чистый working tree (git status пустой)
  • src/ имеет FSD-разметку (или layered-эквивалент)
  • package.json с build/lint/test скриптами
  • запуск из корня репо

ОПЦИИ
  --skip=<layers>        Пропустить слои (csv). По умолчанию для overnight
                         используй --skip=5,6 (без декомпозиции fat-pages
                         и app) — Layer 5/6 несут UI-регрессионный риск.
  --layer=<N>            Прогнать ТОЛЬКО один слой (0..8).
                         Layer 8 = docs-sync (codemaps + CLAUDE.md).
  --resume               Продолжить незавершённую сессию (читает state.json).
  --time-budget=<Nh>     Жёсткий лимит времени (default 6h). Останавливается
                         на чистом коммите при превышении.
  --branch=<name>        Создать и работать на этой ветке вместо HEAD.
  --setup-smoke          Если в проекте нет Playwright — установить его
                         и сгенерировать минимальный @smoke-набор
                         (app shell + main landmark + login form, если
                         есть auth) ДО запуска Layer 0. Делает отдельный
                         коммит chore(test): bootstrap. После этого
                         Layer 5/6 проходят с реальным smoke-gate'ом.
  --dry-run              Только pre-flight + architect-планы по всем слоям,
                         без правок и коммитов.
  --help, -h             Показать это сообщение и выйти.

ТИПИЧНЫЕ СЦЕНАРИИ
  /dm812-fsd-refactor-loop --skip=5,6 --time-budget=6h
      → безопасный overnight: layers 0-4 + 7. Утром получишь SUMMARY.md.

  /dm812-fsd-refactor-loop --resume
      → продолжить вчерашнюю прерванную сессию.

  /dm812-fsd-refactor-loop --layer=3
      → только features/, surgical-блок (dedup helpers, query keys).

  /dm812-fsd-refactor-loop --branch=refactor/auto-2026-05-09
      → новая ветка, не трогает main.

  /dm812-fsd-refactor-loop --dry-run
      → только планы от architect по всем слоям, ноль правок.

  /dm812-fsd-refactor-loop --setup-smoke
      → сначала bootstrap Playwright + минимальный smoke-набор,
        потом полный пайплайн (включая Layer 5/6 с реальным smoke-gate).

АРТЕФАКТЫ
  Сессия пишет в КОРЕНЬ ПРОЕКТА (легко открыть в IDE):
    <project-root>/.refactor-report/<session-id>/
      ├── state.json              (для --resume)
      ├── baseline-{build,lint,test,knip}.txt
      ├── architect-layer<N>.md   (план каждого слоя)
      ├── cleaner-layer<N>.md     (отчёт refactor-cleaner)
      ├── reviewer-layer<N>.md    (отчёт code-reviewer)
      ├── knip-after-layer<N>.txt
      └── SUMMARY.md              (читай первым утром)

  .refactor-report/ автоматически добавляется в .gitignore при первом
  запуске отдельным коммитом, чтобы артефакты не попадали в PR.

КАК ОСТАНОВИТЬ
  • Ctrl+C в интерактивной сессии — скилл доделает текущий verify-gate
    и остановится на чистом коммите.
  • Скилл сам остановится при 3 подряд failed-слоях, грязном дереве,
    или превышении --time-budget.

ЧТО НЕ ДЕЛАЕТ (намеренно)
  • Не пушит ничего на remote — только локальные коммиты.
  • Не трогает supabase/, services/, миграции, edge-функции.
  • Не изменяет package.json deps кроме одного — knip (если отсутствует).
  • Не amend'ит и не --no-verify.
  • Layer 5 (pages) и 6 (app) skip'аются по умолчанию для overnight runs:
    они трогают UI-state и требуют браузерной проверки. Если нужен полный
    проход — запускай днём без --skip и будь рядом.

УТРОМ
  Открой <project-root>/.refactor-report/<session-id>/SUMMARY.md —
  там список коммитов, метрики, deferred items для следующей сессии.
```

После печати help-блока — STOP. Не запускай pre-flight, не трогай файлы.

## Invocation

The orchestrator (you, Claude Code main session) reads this skill and runs the loop. Suggested invocation form from the user side:

```
/dm812-fsd-refactor-loop                          # full pass, layers 0-8
/dm812-fsd-refactor-loop --skip=5,6               # safe overnight (no fat-page split, no app)
/dm812-fsd-refactor-loop --resume                 # continue interrupted session
/dm812-fsd-refactor-loop --layer=3                # single layer only
/dm812-fsd-refactor-loop --time-budget=4h         # bound total time
/dm812-fsd-refactor-loop --branch=refactor/auto   # work on branch instead of HEAD
```

If the user did not specify args, default to `--skip=5,6 --time-budget=6h` (safe overnight).

## Final report

At end of run (success or halt) write `<session-dir>/SUMMARY.md` with:
- Layers completed / skipped / failed.
- Commits produced (hashes + one-line each).
- Build/lint/test/knip delta vs baseline.
- Net LOC delta (`git diff <start>..HEAD --stat`).
- Deferred items (review findings worth a follow-up session).
- Suggested next session: which deferred items to tackle first.
- Codemaps regenerated: yes/no, list of files written to `docs/CODEMAPS/`.
- CLAUDE.md sync status: refreshed paths + Codemaps section verified.

Echo the SUMMARY.md path to the user as the last action so they wake up to a single readable digest, not 200 lines of tool output.
