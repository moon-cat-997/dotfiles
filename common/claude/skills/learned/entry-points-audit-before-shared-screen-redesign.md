---
name: entry-points-audit-before-shared-screen-redesign
description: Mandatory pre-implementation audit when redesigning a screen/component used in multiple places. Surfaces hidden entry points, edge cases, and shared-state coupling before plan is locked.
---

# Entry-Points Audit Before Shared-Screen Redesign

**Extracted:** 2026-04-27
**Context:** Applies before any non-trivial redesign of a screen, sheet, or shared component that is reachable from more than one navigation path.

## Problem

A user asks to "redesign this screen" — but the screen is actually a junction of many flows: feed cards, my-games lists, push notifications, deep links, post-create redirects, post-edit redirects, share-link landings, cancellation propagation, etc. Without enumerating every entry point and every (role × type × state) permutation up front, the implementation is guaranteed to ship with broken cases that surface only after QA opens follow-up tickets. Each "I forgot about that flow" turns into a new edit cycle.

The original QA bug in this session was a downstream symptom of one of those gaps: the approval banner never appeared because there was no Supabase realtime subscription on `game_participants` — the app only invalidated React Query caches on local mutations. The bug looked like "missing UI element" but was actually "missing data sync." That root cause was invisible from the surface design ask and only became visible after a structured audit.

## Solution

Before locking any plan that touches a multi-entry surface, dispatch an `Explore`-type agent (or do the audit yourself if scope is small) with these 8 explicit directions. Don't merge them into one vague "explore the screen" prompt — the structure is what catches blind spots.

1. **Navigation entry points** — grep every `router.push|replace|navigate` and `<Link>` targeting the screen. Include feed, lists, search, profile, map, modals.
2. **Notifications & deep links** — find the notification creation hooks, push handler, and `app.json`/`app.config.ts` scheme. List every notification *type* that opens this screen and what role+state combination each implies.
3. **Edit flow round-trip** — what happens after `edit-foo/[id]` saves? Where does it `replace()` to, and does the screen re-fetch?
4. **Cancel/leave flows** — does the screen close, stay, or re-render? Are other clients notified?
5. **Special states** — empty data, full capacity, cancelled, in-the-moment-of-transition (e.g. `now == start_time`), deleted parent record, anonymous user (no session) hitting deep link.
6. **Realtime updates** — does the existing code subscribe to changes on the underlying tables? If not, the redesign may amplify a stale-data bug that previously hid in the noise.
7. **Shared components** — which components used by the old version are also used elsewhere? List exact file paths so the cleanup phase doesn't accidentally delete something live.
8. **Tests & snapshots** — if any exist, the redesign must not silently break them.

Then convert each finding into either a plan task or an explicit "out of scope, known issue" note. Don't paper over gaps; surface them so the user can decide.

## Example

In this session, the structured audit (≤600 words from one Explore agent) surfaced:

- `ParticipantGameDetailsScreen` was dead code, never routed — the whole-screen base I was about to extend.
- 6 distinct notification types all funnel into `/game/[id]`, each implying a different role+state combination.
- Anonymous deep-link visitors loaded the screen without crashing but with no usable actions — needed an explicit auth CTA.
- No realtime subscription on `game_participants` — root cause of the QA bug, not the UI.
- `status='full'` had no handling in the join path.
- `MyGamesScreen` reuses the screen with `?readonly=1` — must suppress every action button.

Without the audit, at least 3 of those would have shipped broken and required follow-up tickets.

## When to Use

Trigger this skill when **all** of the following are true:

- The user is asking for a redesign, refactor, or "make it match Figma" on a screen/component
- The target is reachable from more than one place in the app (check by grepping its component name across `app/` and `src/`)
- The change touches role-dependent UI, footer/CTA buttons, or anything that varies by state

Skip when:

- The change is purely cosmetic and contained (color tweak, icon swap)
- The component is leaf-level (only one parent imports it)
- The user has explicitly time-boxed the work and accepts iteration

## Anti-pattern

Don't perform the audit *after* writing the implementation as "verification." The point is to feed findings into the plan so the user signs off on the right scope, not to discover late that you missed a flow. Audit → plan → confirm → implement, in that order.
