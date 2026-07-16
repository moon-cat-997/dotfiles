# Global Instructions

## Always load relevant skills before domain-specific work

Skills do not auto-invoke. Before starting work in a domain that has a dedicated skill, **invoke the skill via the `Skill` tool first**. Domain-specific skills contain canonical rules and gotchas (RLS traps, migration filename requirements, view security, etc.) that are easy to miss when relying on memory or prior context. Read the skill, then code.

Trigger map (load these proactively, not on demand):

| Touching | Load before any work |
|---|---|
| Supabase (DB, Auth, Edge Functions, Realtime, Storage, RLS, migrations, MCP) | `Skill(supabase:supabase)` and `Skill(supabase:supabase-postgres-best-practices)` |
| Postgres specifically | `Skill(ecc:postgres-patterns)` |
| Generic DB migrations across stacks | `Skill(ecc:database-migrations)` |
| Anthropic Claude API / SDK code | `Skill(claude-api)` |
| Figma URL or design import | `Skill(figma:figma-generate-design)` (and `Skill(figma:figma-use)` before any `use_figma` tool call) |
| Building MCP servers | `Skill(ecc:mcp-server-patterns)` |
| TDD / test-first workflow | `Skill(ecc:tdd-workflow)` |

If you're unsure whether a skill exists for a domain, scan the available-skills list in the system reminder. Loading a skill is cheap and idempotent — invoking it again on a related task is fine.

**Why:** during one session I edited Supabase migration filenames manually instead of using `supabase migration new`, which broke `db push` ordering and required an `--include-all` workaround. The exact rule is in `Skill(supabase:supabase)` ("When you need a new migration SQL file, always create it with `supabase migration new <name>`"). I had auto-memory on the same topic, but a skill carries the canonical superset — load it first.

## Database migrations and seed data

Whenever a new migration changes schema in a way that affects existing seed data (adding NOT NULL columns, adding/tightening CHECK constraints, renaming/removing columns, changing types), **also audit and update the seed file(s)** in the same change.

**Why:** A migration that passes in isolation can still break `db reset` / fresh environments because the seed file is no longer schema-compatible. The error surfaces only when someone actually runs the seed (often a teammate, CI, or the next session) and is annoying to chase down.

**How to apply:**
- After writing a migration, grep the seed files (`supabase/seed.sql`, `seeds/`, fixtures, test factories) for the affected table/column.
- For NOT NULL additions: add the new column to every INSERT and provide a sensible default value.
- For CHECK additions: verify all seeded values pass; update or note exceptions.
- For renames/removals: update column lists.
- Run `supabase db reset` (or equivalent) locally to confirm before committing.
- Treat the seed file as part of the migration's scope — do not ship the migration without updating it.

## Supabase migration filenames — never edit the timestamp

When creating a new Supabase migration, **always** use `npx supabase migration new <name>` and **leave the auto-generated timestamp prefix alone**. Do not rename the file to a manually-chosen timestamp, do not pick a "future" timestamp to be ahead of older numeric-prefixed migrations, do not flatten to `NNN_…sql`.

**Why:** `db push` compares lexicographically. The CLI generates the timestamp from current UTC, which is monotonically larger than any timestamp that's already been applied to remote (because remote-latest was applied at some moment ≤ now). The moment you hand-pick a "future" timestamp like `20260508120000` while real time is `08:50`, the next CLI-generated migration takes `0851xx` from real clock — which is **less** than your synthetic future stamp — and `db push` rejects it as "in the past" with `Found local migration files to be inserted before the last migration on remote database`. You then have to use `--include-all` (which disables the safety check) or rename again.

**How to apply:**
- Always run `npx supabase migration new <descriptive_name>` for a new migration. Take whatever timestamp it gives.
- If you need a second migration in the same minute, run `migration new` again — seconds resolution prevents collision.
- Never rename an unapplied migration to a different timestamp unless the file truly clashes with the auto-generated one (almost never).
- Never rename an **applied** migration — it desyncs `supabase_migrations.schema_migrations` and requires `migration repair` for every renamed file.
- Old numeric-prefix migrations (`NNN_xxx.sql`) that already exist in repo and are applied on remote: leave them alone. They don't participate in the "is this in the past?" check because they're already in `schema_migrations`. They just sit as historical artifacts.
- If you encounter the "in the past" error and you didn't hand-edit any timestamp: run `npx supabase migration list`, find the highest applied id, and look at your local files — there is a stale unapplied file with a lower timestamp. Either apply it via `--include-all` (after verifying it isn't a leftover) or delete it.
