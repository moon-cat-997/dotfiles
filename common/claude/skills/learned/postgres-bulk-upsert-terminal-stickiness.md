# Postgres bulk-upsert terminal-state stickiness

**Extracted:** 2026-05-03
**Context:** When two independent writers update a row's lifecycle column and one of them doesn't know about the full state machine.

## Problem
A `bulk_upsert(...)` style RPC that takes a fresh `status` from an external source (Polymarket sync, Stripe webhook, third-party CRM) and unconditionally writes `set status = excluded.status` will fight with any other code path that advances `status` to a downstream terminal state (e.g., a periodic cascade flipping `closed` → `resolved`, or an admin workflow archiving items).

Symptom: the cascade reports the same logical work every cycle (e.g., "resolved 200..500 events" indefinitely), but row-count totals barely grow. `resolved_at` / `updated_at` columns get clobbered on each flap, so the timestamp loses business meaning ("when did this resolve" answers `now()` regardless of when the event actually decided).

## Solution
Make terminal states sticky in the upsert's `ON CONFLICT DO UPDATE` branch with a `CASE`:

```sql
on conflict (polymarket_id) do update
  set status = case
                 when ev.status in ('resolved', 'archived') then ev.status
                 else excluded.status
               end,
      ...  -- other fields keep being upserted normally
```

Transitions then go in one direction only:
`open → closed → resolved → archived` (downstream paths still own the forward steps; the upsert just stops moving rows backward).

Do NOT try to fix this on the application side by filtering payload pre-RPC — race conditions between application read and RPC write will leak the bug back. The DB is the only place where the invariant can be enforced atomically.

## Example
PolyBet had a sync from Polymarket Gamma (every minute) writing `events.status` from `{open|closed|resolved}` and a separate `cascade_event_lifecycle()` flipping events to `resolved` once all child markets terminated. Polymarket frequently leaves `event.resolved=null` even on de-facto resolved events, so the sync wrote `closed`, undoing the cascade.

Symptoms in production:
- `cascadeEventsTick` reported `resolved=200..520` every 5 min indefinitely
- `select count(*) from events where status='resolved'` barely grew between cycles
- `events.resolved_at` was within the last 5 minutes for hundreds of rows that had been resolved hours/days ago

Fix: 6-line `CASE` in `bulk_upsert_events` ON CONFLICT branch (migration 073). Next cascade tick after the migration: backlog drained from 249 → 24 in one cycle, then steady-state 0..few.

## When to Use
Trigger this skill when:
- A periodic batch job repeats the same logical work indefinitely without converging
- `created_at` / `resolved_at` / `updated_at` columns contain values that look fresher than the underlying business event
- Two writers touch the same lifecycle column AND at least one of them gets its source data from an external system that doesn't model the full state machine
- The DB has a reasonable lifecycle ordering (e.g., `open → closed → resolved → archived`) where later states should not regress

## Anti-patterns
- Filtering downgrades on the application side (race-prone)
- Adding triggers that revert downgrades (extra writes, slower, harder to reason about)
- Renaming the column to `external_status` and computing `effective_status` in views (works but doubles the concept count; avoid unless multiple consumers genuinely need both)
