---
name: atomic-rpc-with-trigger-aware-mutations
description: Use when designing a Postgres/Supabase RPC that must atomically mutate a parent row + cascade child-row state changes while coexisting with existing AFTER UPDATE triggers that would otherwise produce wrong/duplicate notifications. Combines server-side re-derivation (race safety), trigger-aware semantics (encode actor intent in a data column), and JSONB-patch updates (partial form mutations).
---

# Atomic RPC with Trigger-Aware Mutations (Postgres/Supabase)

**Extracted:** 2026-04-27
**Context:** Multi-row state changes in Postgres where (a) the change must be race-safe against concurrent writes, (b) existing AFTER UPDATE triggers would produce wrong/duplicate notifications, and (c) the frontend wants to send a partial patch.

## Problem

Three problems that usually show up together:

1. **Race conditions** — frontend reads "who needs to change" then sends a list of IDs to the server. Between the read and the write, the truth changes.
2. **Trigger noise** — existing triggers fire on every status change (e.g. `participant_left` notification on `status='cancelled'`). When the *organizer* initiates the cancellation, sending them a notification about their own action is spam.
3. **Partial patches** — UI form lets the user change any subset of fields. Hand-coding RPC parameters per field is brittle.

## Solution

A single SECURITY DEFINER plpgsql RPC that:

1. **Locks** the parent row with `FOR UPDATE` and authorizes (`auth.uid() = creator_id`).
2. **Re-derives** the affected child set on the server (don't trust the frontend's list).
3. **Encodes the actor's intent in a data column** the trigger can read — e.g. `cancel_reason = 'time_conflict'` — and modifies the trigger to early-return when it sees that value.
4. **Inserts the correct notification** (the one that actually matches the new semantics) in the same transaction.
5. **Applies the patch** as JSONB with `COALESCE(p_patch->>'col', col)` for each whitelisted column. `NULLIF(...,'')::type` for typed-nullable columns. `CASE WHEN p_patch ? 'col' THEN ... ELSE col END` for fields that should be settable to NULL.

Everything runs in one transaction; mid-flight failures roll back cleanly.

## Example

```sql
CREATE OR REPLACE FUNCTION public.update_game_with_conflict_removal(
  p_game_id UUID, p_patch JSONB, p_buffer_minutes INT DEFAULT 30
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_actor UUID := auth.uid(); v_creator_id UUID; v_window TSTZRANGE; ...
BEGIN
  SELECT creator_id, ... INTO v_creator_id, ... FROM games WHERE id = p_game_id FOR UPDATE;
  IF v_creator_id <> v_actor THEN RAISE EXCEPTION 'not_authorized'; END IF;

  -- Re-derive on server, never trust caller's player_id list:
  WITH conflicting AS (SELECT player_id FROM ... WHERE EXISTS (... && v_window)),
       cancelled AS (UPDATE participants SET status='cancelled', cancel_reason='time_conflict'
                     FROM conflicting ... RETURNING ...)
  ...

  -- JSONB patch with whitelist:
  UPDATE games SET
    title       = COALESCE(p_patch->>'title', title),
    start_time  = COALESCE((p_patch->>'start_time')::timestamptz, start_time),
    is_public   = COALESCE((p_patch->>'is_public')::boolean, is_public),
    surface     = CASE WHEN p_patch ? 'surface' THEN NULLIF(p_patch->>'surface','') ELSE surface END,
    facilities  = CASE WHEN p_patch ? 'facilities'
                       THEN COALESCE((SELECT array_agg(value) FROM jsonb_array_elements_text(p_patch->'facilities')), ARRAY[]::TEXT[])
                       ELSE facilities END
  WHERE id = p_game_id;
END $$;
```

And the trigger gets a one-line guard:

```sql
IF NEW.status = 'cancelled' THEN
  IF NEW.cancel_reason = 'time_conflict' THEN RETURN NEW; END IF;  -- skip self-notification
  INSERT INTO notifications ...;
END IF;
```

## When to Use

Activate when you see all three of these in the same task:

- Postgres/Supabase backend with existing AFTER UPDATE/INSERT triggers
- A user action that changes a parent row + cascades cancellations/notifications to child rows
- Frontend wants to call a single endpoint and not orchestrate two-phase commits

Don't use for simple single-row updates — `useUpdateMutation` with a regular `.update(patch)` is fine. The complexity here is justified only when triggers + cascades + race-safety all matter.

## Anti-patterns this avoids

- **Frontend-driven removal lists** — vulnerable to last-second joiners.
- **Disabling triggers temporarily** — leaves the system in inconsistent state if function fails.
- **Sending two RPCs (`remove`, then `update`)** — partial-failure hell.
- **Per-column RPC parameters** — re-write the function every time the form grows a field.
