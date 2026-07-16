# supabase db push blocked by a stale early-timestamp migration

**Extracted:** 2026-05-31
**Context:** `supabase db push` to a linked remote refuses because a committed
local migration has a timestamp earlier than the latest one already applied on
remote (an out-of-order gap). Hit in buy-by-power when pushing Sprint-4 migrations.

## Problem
`db push` fails with:
> Found local migration files to be inserted before the last migration on
> remote database. Rerun the command with --include-all flag...

This happens when a local migration (e.g. `20260518172808_*.sql`) was never
applied to remote, and newer migrations exist on remote with later timestamps.
`db push` is all-or-nothing for pending migrations, so the stale one blocks
everything. `--include-all` applies the stale one too AND disables the ordering
safety check — don't run it blindly on a shared DB.

## Solution — investigate before choosing
1. `npx supabase db push --dry-run` — confirms exactly which file is "before last".
2. Read that migration: what does it create (tables/functions)?
3. Check whether its objects already exist on remote (read-only):
   `npx supabase db dump --linked --schema public -f /tmp/remote.sql`
   then grep for the table/function names.
   - **Exists on remote** (applied manually, not recorded) ->
     `npx supabase migration repair --status applied <version>` to record it,
     then a normal `db push` applies only your new migrations (no --include-all).
   - **Does NOT exist** -> it's genuinely pending; applying it is correct.
     Use `echo y | npx supabase db push --include-all` (it applies the stale one
     too — verify that's acceptable on the shared DB first).

## Notes
- `db push` does NOT run `seed.sql`. To get seed/demo data onto a cloud project,
  run the SQL via the Supabase SQL Editor or `supabase db query --linked -f file.sql`.
- Writing INSERT/DELETE seed data to a shared dev DB may be blocked by the agent
  safety classifier unless the user explicitly authorized that exact action.
- Prevention (already in CLAUDE.md): never hand-edit migration timestamps;
  always create via `supabase migration new`.

## When to Use
Any time `supabase db push` reports "inserted before the last migration on
remote", or before reaching for `--include-all`.
