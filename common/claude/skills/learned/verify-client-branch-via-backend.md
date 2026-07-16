# Verify a Hard-to-Observe Client Branch Against a Live Backend

**Extracted:** 2026-06-29
**Context:** Black-box testing a mobile/SPA build on a real device against a live
backend, when the behaviour you care about isn't directly visible in the UI and
you can't easily instrument the client.

## Problem
Two recurring blockers when verifying a fix/feature end-to-end on a device:
1. A query/action silently uses some input (e.g. a fallback location) and the UI
   gives no clue what value it *actually* sent — so you can't prove the fix.
2. A branch only runs under conditions you can't reproduce on the device
   (e.g. "no results nearby" → fallback path), so it never executes in your test.

## Solution
Two levers, used together:

1. **Recover the real input from a backend side-effect.** If the action writes a
   row (subscription, log, audit, analytics, last-query table), query that row to
   read exactly what the client sent (coords, filters, params). Diff it against
   the old/hardcoded value to *prove* the new behaviour — no client instrumentation
   needed.

2. **Force the branch by constraining inputs.** To exercise a
   "primary returns empty → fallback" path without moving the device or seeding
   data, narrow a user-controllable filter to a value that has *no* matching data
   nearby. The primary query returns empty and the fallback fires. Restore the
   setting afterwards (and verify the restore in the DB).

## Example (Parkly — Expo + Supabase)
- **Proved real GPS:** the find-search writes an alert subscription on each run.
  After tapping search, queried `spot_alert_subscriptions.geom` for the user and
  saw the device's real coords (32.0906, 34.8599) instead of the hardcoded
  Tel-Aviv fallback (32.069, 34.774) every prior run had used.
- **Forced the Google-Places fallback:** set the marking filter to `blue_white`
  only (no blue_white seed within 800 m) → crowdsourced RPC returned empty →
  the lots fallback rendered. Restored prefs to `{blue_white, lot, free}` after.

## When to Use
E2E-verifying a specific code path on a real device/build against a live DB when
(a) you can't read the value the client used, or (b) the branch needs conditions
you can't trivially create — and either a server-side write or a user-controllable
filter gives you a lever.
