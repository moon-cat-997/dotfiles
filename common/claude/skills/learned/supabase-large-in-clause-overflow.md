# Supabase HeadersOverflowError on large `.in()` queries — push to SQL RPC

**Extracted:** 2026-05-03
**Context:** PostgREST under Supabase rejects requests whose URL exceeds ~16KB of headers, which the supabase-js `.in('column', [...lots of UUIDs])` builder can hit silently.

## Problem
Code like this:

```ts
const { data, error } = await supabase
  .from('markets')
  .select('event_id, status')
  .in('event_id', eventIds);  // eventIds.length > ~400 UUIDs
```

generates a URL like `?event_id=in.(uuid1,uuid2,...,uuid500)`. With 36-char UUIDs + commas, ~500 ids gives ~18,500 chars — over the typical 16KB header limit. Fails with:

```
TypeError: fetch failed
Caused by: HeadersOverflowError: Headers Overflow Error (UND_ERR_HEADERS_OVERFLOW)
hint: HTTP headers exceeded server limits (typically 16KB).
      Your request URL is 19597 characters.
      If filtering with large arrays (e.g., .in('id', [200+ IDs])),
      consider using an RPC function instead.
```

Chunking helps but is brittle: as the catalog grows, the chunk size needed shrinks; you also pay N round-trips. Worse, when the query is already inside an aggregation (e.g., "fetch every child market for these candidate events"), chunking forces an in-memory join and N+1 patterns.

## Solution
Write a SQL function that does the whole operation in one server-side call, expose it via `supabase.rpc()`, and call it once.

```sql
create or replace function cascade_event_lifecycle()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_archived int := 0;
  v_resolved int := 0;
begin
  with candidate_events as (
    select id, status from events where status in ('open','closed','resolved')
  ),
  agg as (
    select ce.id, ce.status as event_status,
           bool_and(m.status = 'archived') as all_archived,
           bool_and(m.status in ('resolved','archived')) as all_terminal,
           bool_or (m.status = 'resolved') as any_resolved
    from candidate_events ce
    join markets m on m.event_id = ce.id
    group by ce.id, ce.status
  ),
  do_archive as (
    update events set status='archived', archived_at=now()
    where id in (select id from agg where all_archived and event_status <> 'archived')
    returning 1
  ),
  do_resolve as (
    update events set status='resolved', resolved_at=now()
    where id in (select id from agg where all_terminal and any_resolved
                                       and event_status not in ('resolved','archived'))
    returning 1
  )
  select (select count(*) from do_archive), (select count(*) from do_resolve)
  into v_archived, v_resolved;

  return jsonb_build_object('archived', v_archived, 'resolved', v_resolved);
end; $$;

revoke all on function cascade_event_lifecycle() from public, anon, authenticated;
grant execute on function cascade_event_lifecycle() to service_role;
```

Caller becomes a one-liner:

```ts
const { data, error } = await supabase.rpc('cascade_event_lifecycle');
return (data ?? { resolved: 0, archived: 0 }) as { resolved: number; archived: number };
```

## When to Use
- `HeadersOverflowError` / `UND_ERR_HEADERS_OVERFLOW` in Supabase logs
- Hint message `Your request URL is N characters` where N > 15000
- A loop chunking `.in('id', slice)` over a large id set, especially when the next step joins or aggregates the result
- Any "fetch all children of these N parents and aggregate" where N > 200

## When NOT to use
- Small id sets (< 100). The RPC overhead (function definition, migration, revoke/grant) isn't worth it.
- Single-shot ad-hoc analytics queries — leave them in app code.
- When the operation needs to run as the calling user's role (RPC `security definer` runs as the function owner). Plain queries respect RLS for the caller; RPCs typically don't.

## Side benefit
Server-side aggregation often runs 10-100× faster on large catalogs because it avoids N round-trips and uses the planner's stats. The PolyBet `cascadeEventLifecycle` went from 5+ chunked round-trips of `.in(... 500 ids)` (each failing intermittently) to one ~50ms RPC call.
