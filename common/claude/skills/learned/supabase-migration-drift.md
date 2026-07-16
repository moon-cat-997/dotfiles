# Supabase migration drift: MCP apply_migration vs CLI db push

**Extracted:** 2026-04-19
**Context:** Supabase projects that use both CLI (`supabase db push`) and MCP (`mcp__plugin_supabase_supabase__apply_migration`) to apply migrations.

## Problem

`supabase db push` fails with:
```
Remote migration versions not found in local migrations directory.
```
And `migration list --linked` shows an orphan timestamp-format version on Remote
(e.g. `20260419081457`) with no matching Local file, while local numeric-prefix
migrations (e.g. `047_*.sql`) are missing from Remote.

## Root Cause

Both channels write to `supabase_migrations.schema_migrations` but with different
version naming:
- **CLI** (`db push`): uses the filename prefix as-is (`047`, `048`).
- **MCP** (`apply_migration`): generates its own timestamp version (`YYYYMMDDHHMMSS`)
  at the time of the call, ignoring any local file.

If both are used on the same migration, the SQL runs against the DB but the
history table gets two independent entries — CLI sees orphan timestamps it can't
match to files and refuses to push.

## Solution

1. **Diagnose** — confirm the conflict:
   ```bash
   npx supabase migration list --linked
   ```
   Look for rows where Remote has a 14-digit timestamp and Local is empty.

2. **Verify SQL identity** — pull the orphan's SQL from Dashboard
   (Database → Migrations) or:
   ```sql
   SELECT version, name, statements
   FROM supabase_migrations.schema_migrations
   WHERE version = '<timestamp>';
   ```
   Compare byte-for-byte with the local file that "should" own those changes.

   **Comment-only differences are expected.** `schema_migrations.statements`
   stores only the executed SQL, stripped of leading `--` comments from the
   local `.sql` file. If the executable bodies (CREATE/ALTER/...) match and
   only the prose comments differ, treat them as identical.

3. **Re-link history** (when SQL is identical — schema is already correct):
   ```bash
   npx supabase migration repair --status reverted <timestamp>
   npx supabase migration repair --status applied <local-version>
   npx supabase db push   # applies remaining untouched local migrations
   ```
   `reverted` only removes the history row; it does not run a DOWN migration.
   `applied` marks a local file as executed without running it.

4. **If SQL differs** — `npx supabase db pull` to save the orphan as a local file,
   reconcile manually, then push.

## Example

Observed in PolyBet:
- Local: `047_markets_feed_perf.sql`, `048_events_hierarchy.sql`, `049_admin_create_demo_event.sql`
- Remote: `20260419081457` (orphan) + 001–046 clean

SQL of `20260419081457` matched `047_markets_feed_perf.sql` exactly → MCP had
been used to apply it in an earlier session. Fix:
```bash
npx supabase migration repair --status reverted 20260419081457
npx supabase migration repair --status applied 047
npx supabase db push  # applied 048, 049
```

## When to Use

Trigger conditions:
- `supabase db push` errors about "Remote migration versions not found"
- `migration list --linked` shows asymmetric rows
- A project has both CLI and MCP Supabase workflows configured

## Prevention

Pick **one** channel per project and stick to it:
- Prefer **CLI** as source of truth — files in `supabase/migrations/` are
  reviewable, diff-able, reproducible.
- Use **MCP `apply_migration`** only for ad-hoc exploratory DDL that will **not**
  have a corresponding file. If you later want a file, `supabase db pull` it.
- Document the chosen channel in `CLAUDE.md` / project README.

**Always commit & push the migration file before running `db push`.** A common
recurrence pattern: dev applies `NNN_*.sql` from machine A, forgets to commit,
then on machine B applies the same SQL via Dashboard SQL Editor → remote
`schema_migrations` gets a timestamp row → next `db push` from either machine
sees drift. After repair, verify `git status` for untracked migration files and
that the branch is pushed to origin.
