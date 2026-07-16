# Silent Supabase Mutation Failure → Check DB Constraint via Postgres Logs

**Extracted:** 2026-05-24
**Context:** React Native/Web + Supabase. A mutation (insert/update) appears to do
nothing — a modal/sheet stays open, no toast, no crash — but the DB row is unchanged.

## Problem
A write via `supabase.from(...).update(...)` / `.insert(...)` silently fails. The UI
only closes the sheet / shows success in its `onSuccess` callback, so a rejected write
leaves the sheet open with no visible feedback (the `onError` toast is easy to miss or
auto-dismisses). Common when a UI enum gains new option values but the DB `CHECK`
constraint (or RLS policy) was never extended to allow them.

## Solution
Diagnose in this order — do NOT just retry the tap or assume the click missed:

1. **Confirm the write reached the DB and was rejected** — read the Postgres container
   logs directly. They print the exact failing SQL + reason:
   ```bash
   docker logs supabase_db_<project> --since 5m 2>&1 \
     | grep -iE "error|violates|constraint|policy" | tail -25
   ```
   Look for `violates check constraint "..."` or `new row violates row-level security`.

2. **If it's a CHECK constraint**, dump its definition and compare against the UI enum:
   ```bash
   psql ... -c "SELECT pg_get_constraintdef(oid) FROM pg_constraint
                WHERE conname='<table>_<col>_check';"
   ```
   Grep the client component for the values it sends (e.g. a `type X = 'a' | 'b' | ...`).
   The drift between the two sets is the bug.

3. **If RLS**, check that an UPDATE has BOTH a USING and WITH CHECK policy for the actor,
   and remember an UPDATE silently returns 0 rows without a SELECT policy.

4. **Fix** by widening the constraint in a NEW migration (`supabase migration new <name>`,
   never hand-edit the timestamp). Apply the same SQL to the local DB directly (psql /
   `execute_sql`) so you can re-test in the SAME session without `db reset` wiping state.
   A `CHECK` widening is reset-safe and needs no seed change (verify seed doesn't use the col).

## Example
Sheet sends `cancel_reason: 'game_full'`; constraint only allowed
`cannot_attend|injured|other_game|personal|other|time_conflict|game_cancelled`.
`game_full` (+ 4 other organizer reasons) were never added → every removal except
"other" failed. Fix = `ALTER TABLE ... DROP CONSTRAINT ...; ADD CONSTRAINT ... CHECK (... IN (<full set>))`.

## When to Use
- A Supabase insert/update "does nothing": sheet/modal stays open, row unchanged, no crash.
- A mutation works for SOME option values but not others (classic enum↔constraint drift).
- Before blaming the UI tap/coordinates, check the DB logs for a rejected statement.
