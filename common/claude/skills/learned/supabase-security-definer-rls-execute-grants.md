# Supabase: EXECUTE grants on SECURITY DEFINER RLS helper functions

**Extracted:** 2026-05-24
**Context:** Supabase/Postgres. You wrote a `SECURITY DEFINER` predicate function (e.g. `is_admin(uuid)`, `_is_game_creator(...)`) and reference it inside RLS policies (`USING (public.is_admin(auth.uid()))`). You want to lock down who can call it without breaking RLS.

## Problem
Two traps bite here:

1. **A SECURITY DEFINER function used in an RLS policy still needs the *querying* role to hold `EXECUTE`.** If `authenticated` lacks EXECUTE, every query against the protected table fails with `ERROR: permission denied for function <fn>` — RLS does NOT call it under the definer's rights for the permission check. So you cannot "just revoke from authenticated" to hide the function.
2. **Revoking `FROM PUBLIC` is not enough to close the function to anon.** `CREATE FUNCTION` grants EXECUTE to `PUBLIC` by default, and Supabase *additionally* grants it explicitly to `anon`, `authenticated`, `service_role`. Revoking only `FROM PUBLIC` leaves the explicit `anon` grant intact, so an unauthenticated client can still call it via PostgREST RPC (`POST /rest/v1/rpc/<fn>`) — an information oracle (e.g. "is this uuid an admin?").

A security reviewer may suggest "revoke EXECUTE from authenticated" — that's wrong: it either does nothing (PUBLIC still grants it) or, if PUBLIC is also revoked, it breaks RLS for all users.

## Solution
To expose an RLS helper to `authenticated` only (required for RLS) AND close the anon/PUBLIC RPC oracle:

```sql
REVOKE EXECUTE ON FUNCTION public.is_admin(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.is_admin(uuid) FROM anon;   -- explicit Supabase grant, not covered by PUBLIC revoke
GRANT  EXECUTE ON FUNCTION public.is_admin(uuid) TO authenticated;  -- REQUIRED for RLS policy evaluation
```
`service_role` keeps access implicitly (it bypasses grants/RLS). The oracle remains callable by any authenticated user — that's inherent to this RLS pattern and is acceptable for low-value predicates.

## Verify empirically (don't guess)
Check the ACL and simulate roles directly against the local DB:

```sql
-- Who currently holds EXECUTE? '=X/owner' segment means PUBLIC.
SELECT proacl FROM pg_proc WHERE proname = 'is_admin';
-- Expect after hardening: {owner=X/owner, authenticated=X/owner, service_role=X/owner}

-- Does RLS still work for an admin? (auth.uid() reads request.jwt.claims->>'sub')
SET ROLE authenticated;
SET request.jwt.claims TO '{"sub":"<admin-uuid>","role":"authenticated"}';
SELECT count(*) FROM public.<protected_table>;   -- should return admin-visible rows
RESET ROLE;

-- Is the anon oracle closed?
SET ROLE anon;
SELECT public.is_admin('<uuid>');   -- expect: ERROR permission denied for function is_admin
RESET ROLE;
```
psql connection for the local stack: `psql "$(supabase status | grep 'DB URL')"` (default `postgresql://postgres:postgres@127.0.0.1:<port>/postgres`). Note `postgres` superuser bypasses RLS — you MUST `SET ROLE authenticated/anon` to test policies.

## Bonus: additive admin read policies
To give admins read-all on a table without weakening existing user policies, add a separate PERMISSIVE policy — multiple PERMISSIVE SELECT policies are OR-combined, so this only *adds* access:
```sql
CREATE POLICY "<table>_select_admin" ON public.<table>
  FOR SELECT TO authenticated USING ( public.is_admin(auth.uid()) );
```
Verify non-weakening: a non-admin's row count must stay the same as before; the admin's must grow.

## When to Use
Adding/auditing any Supabase `SECURITY DEFINER` function referenced in RLS; building an admin/role gate via a helper predicate; a review flags a SECURITY-DEFINER function as a public RPC oracle; you see `permission denied for function` after locking down a function used in policies.
