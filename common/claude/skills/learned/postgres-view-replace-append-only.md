# Postgres CREATE OR REPLACE VIEW is append-only for columns

**Extracted:** 2026-06-02
**Context:** Adding/removing/reordering columns on an existing Postgres view (incl. Supabase migrations). Hit in polybet when extending the `admin_bet_log` view.

## Problem
`CREATE OR REPLACE VIEW` cannot rename, drop, reorder, or insert columns into the middle of an existing view's column list. It can only **append new columns at the end**. Inserting a column in the middle of the SELECT shifts the names of later columns and fails with:

```
ERROR: cannot change name of view column "<existing>" to "<new>" (SQLSTATE 42P16)
```

This passes code review (the SQL looks fine) and only blows up at apply time — e.g. `supabase db reset` / `db push` aborts mid-run, leaving the migration chain half-applied.

## Solution
- When extending a view via `CREATE OR REPLACE VIEW`, add the new columns **strictly at the END** of the SELECT list, after all existing columns in their original order.
- If you genuinely need to insert in the middle, reorder, rename, or drop a column, `DROP VIEW <name>` (cascade-aware) then `CREATE VIEW` — `CREATE OR REPLACE` won't do it.
- Preserve the view's options on replace (e.g. `WITH (security_invoker = on)`) and keep the leading columns byte-identical to avoid the 42P16.

## Example
```sql
-- ❌ Fails 42P16: shares/avg_price inserted before existing `status`
CREATE OR REPLACE VIEW admin_bet_log AS
SELECT b.id, b.stake, b.shares, b.avg_price, b.status, ... FROM bets b ...;

-- ✅ New columns appended at the very end
CREATE OR REPLACE VIEW admin_bet_log
  WITH (security_invoker = on) AS
SELECT
  b.id, b.stake, b.status, /* ...all existing columns, same order... */
  b.shares, b.avg_price            -- appended last
FROM bets b ...;
```

## When to Use
Any time you edit an existing SQL view (Postgres/Supabase) to expose extra columns. If a `db reset`/`db push` fails with SQLSTATE 42P16 "cannot change name of view column", this is the cause — move the new columns to the end or switch to DROP + CREATE.
