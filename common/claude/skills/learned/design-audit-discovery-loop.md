---
name: design-audit-discovery-loop
description: When a tester or stakeholder says "designs don't match" across the whole app (not one screen), run a structured Discovery → Audit → Backlog → Per-screen-approval loop with full Figma inventory + Playwright current-state screenshots before touching any code. Surfaces missing screens, wiring bugs, and false alarms; produces a prioritized backlog with product-blocker questions.
---

# Design Audit Discovery Loop

**Extracted:** 2026-05-01
**Context:** Applies when a tester / PM / designer says "the app doesn't match Figma" or "implement what the designer drew" across multiple screens. Complements `entry-points-audit-before-shared-screen-redesign` (which is per-screen); this one is per-app.

## Problem

When the surface area is "the whole app vs the whole Figma file", the naive approach — open Figma, open the app, eyeball, fix what looks wrong — wastes hours on:

- **False alarms** that look like bugs but are timing artifacts in test screenshots (e.g. "infinite spinner" that's actually a 200ms render before data lands).
- **Routing ambiguity** in tests (e.g. `/orders` resolves to wrong group when both `(buyer)/orders` and `(seller)/orders` exist), which manifests as "screen X shows wrong content" — a phantom bug.
- **Conceptual mismatches** that need product decisions, not code (Figma shows social feed, code has KPI dashboard — both reasonable, only one ships).
- **Missing screens** that look like routing bugs (404 ≠ "broken", may be "never built").
- **Pixel polish** that drowns out actual structural issues.

Without a discovery phase, you either fix things in random order, miss the missing screens entirely, or burn cycles on cosmetics while the seller flow is broken end-to-end.

## Solution

A 4-phase loop: **Discovery → Audit → Backlog → Per-screen approval**. Phase 1 produces all artifacts in batch (no approvals needed); per-screen approvals start at Phase 4.

### Phase 1 — Discovery (batch-allowed, ~2-3h)

Produce these artifacts before any code change:

1. **Full Figma inventory** (`docs/figma-inventory.md`)
   - Use Figma MCP `use_figma` to enumerate every top-level frame on the page (id, name, width × height, x/y).
   - Categorize: real screens (mobile mockups 390×800+) vs components vs artboards/typography. Drop the latter two.
   - Group by role: auth / buyer / seller / admin.

2. **Figma flows mapping** (`docs/figma-flows-mapping.md`)
   - For each prototype URL `?starting-point-node-id=X`, walk `node.reactions[].actions[].destinationId` via `use_figma` to extract the visited graph.
   - Maps each Figma node → existing app route or "MISSING — create new".

3. **Current-state screenshots** (`docs/screenshots/current/{role}/<route>.png`)
   - Playwright spec that logs in per role with demo accounts (from `CREDS.md`), goto each route with **explicit group prefix** (`/(buyer)/feed`, NOT `/feed` — see `expo-router-tab-folder-wiring` for why).
   - `viewport: { width: 393, height: 852 }`, `locale: 'he-IL'` (or whatever the project uses).
   - Skip-if-exists: `if (fs.existsSync(file)) return;` — re-runs are cheap and resumable.
   - `waitUntil: 'domcontentloaded' + waitForLoadState('networkidle', 15s)` + `waitForTimeout(2500)` is the right balance — too short and you photograph mid-render spinners.

4. **Side-by-side audit** (`docs/design-audit.md`)
   - For each route: Figma reference + current screenshot + delta description.
   - Categorize each delta into one of three buckets:
     - **A. Mismatched** — screen exists, design differs → CSS/layout edit
     - **B. Missing** — no file in code → create new
     - **C. Wiring/Bug** — file exists but route 404s, redirects wrong, or doesn't load data → routing or data fix

5. **Prioritized backlog** (`docs/design-backlog.md`)
   - **P0** — blocks MVP (route 404, data hangs, wiring bugs)
   - **P1** — major design / conceptual mismatches user notices
   - **P2** — missing screens to create
   - **P3** — minor pixel polish
   - **Product-blocker questions Q1..QN** — for any conceptual mismatch (Figma vs code), don't code, ask. Examples: "Login is OTP in Figma, password in code — which?" / "Seller home is dashboard in code, social feed in Figma — which?" / "Tier label is `כסף` in code, `סילבר` in Figma — which?"

### Phase 2 — Triage (after Q's answered)

- Drop tasks blocked by Q's the user marks "don't change" (e.g. "login: don't trigger" → drop A1).
- Drop false alarms — spend 5 minutes re-screenshotting with longer wait or explicit group prefix before declaring something a bug. **In one such audit, 3 of 4 P0 turned out to be false alarms.**

### Phase 3 — Smoke test before polish

Before fixing any P3 minor, run a full e2e smoke that creates real data through the entire happy path (`login → list → detail → confirm → checkout → orders`, verifying a row actually lands in DB). If smoke passes, polish is safe; if it fails, fix wiring first.

### Phase 4 — Implementation with per-screen approval

For each P0/P1/P2 task, show the plan (what file + what change + estimated hours), wait for explicit "ок", then implement. Phase 1 (pure docs) and admin polish (per project rule) can be batched without approval.

## Anti-patterns

- ❌ **Skipping Phase 1** — "I'll just open Figma and fix what I see." You will miss missing screens entirely (404s aren't visible from Figma).
- ❌ **Trusting first screenshot** — render-timing creates phantom spinners. Re-screenshot with `networkidle + 2500ms` before reporting a "bug".
- ❌ **Pixel polish before wiring** — fixing colors on a screen that 404s is wasted work.
- ❌ **Coding around product mismatches** — if Figma and code disagree conceptually, ask. Do not pick one silently.
- ❌ **Direct URL navigation in tests without group prefix** — see `expo-router-tab-folder-wiring`.

## Output structure (template)

```
docs/
├── figma-inventory.md           # all frames classified
├── figma-flows-mapping.md       # prototype graphs → routes
├── design-audit.md              # side-by-side, A/B/C buckets, status table
├── design-backlog.md            # P0..P3 + Q1..QN product blockers
├── design-final-summary.md      # written at end with closed/open
└── screenshots/
    ├── figma/
    ├── current/{auth,buyer,seller,admin}/
    └── smoke/
```

## When to use

Trigger when **all** of:
- Stakeholder feedback is multi-screen ("designs don't match" across the app, not one screen)
- A Figma file or design system exists as the reference
- More than ~5 screens are potentially affected

Skip when:
- One screen / one component (use `entry-points-audit-before-shared-screen-redesign` instead)
- Pure cosmetic single-property tweak
- No Figma reference exists (audit has no source of truth)

## Acceptance for the discovery phase itself

The Phase 1 deliverable is "good enough" when:
- [ ] Every Figma frame either has a target route OR is marked "out of scope / not a screen"
- [ ] Every app route either has a Figma reference OR is marked "designed by team without Figma source"
- [ ] Every conceptual mismatch is a numbered Q with options (a/b/c), not a guess
- [ ] At least one full e2e smoke passes (proves baseline isn't broken before fixing details)

## Real-world ROI

In one audit covering ~50 screens:
- 4 alleged "P0 critical bugs" turned out to be 1 real bug + 3 false alarms (URL ambiguity in test spec).
- 3 missing screens were caught that would never have surfaced from "look at Figma" approach.
- 6 product decisions surfaced before code, avoiding 8-12h of "wrong direction" rework.
- ~85% Figma compliance shipped in ~50 hours total, with all critical flows working end-to-end.
