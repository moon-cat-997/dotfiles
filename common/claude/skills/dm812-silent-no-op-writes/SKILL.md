---
name: dm812-silent-no-op-writes
description: Diagnose and harden "silent no-op" state mutations — when a move/update/transition call reports success but the state never actually changed, so a job loops, falsely succeeds, or downstream steps never fire. Use when a CI/cron/pipeline step passes but nothing happens downstream, an item is "stuck" despite success logs, or when writing any verify-after-write / reconcile loop against an SDK that caches reads or no-ops on invalid requests.
origin: personal-dm812
version: 1.0.0
---

# dm812-silent-no-op-writes

**Context:** A pipeline/job step reports success but nothing happens downstream;
a state-mutating call (move / update / transition / upsert) "succeeds" yet the
entity never actually changes state.

## Problem

A mutating call returns without throwing, the code logs `✅ moved to X`, but the
entity never changes state. Because the failure is silent:

- the operation **loops forever** (re-processing the same item every cycle),
- **success is falsely reported**, and
- downstream steps that **gate on the new state never fire**.

Two compounding traps make this hard to debug:

1. **The SDK no-ops instead of throwing** when the request is invalid for the
   current state — e.g. the target status/transition is absent from the
   workflow, a precondition is unmet, or an enum value doesn't exist. A generic
   `Request performed successfully` log line often belongs to a *different*
   request (a comment, a GET), not the mutation.
2. **Verify-after-write is unreliable**: a cached read returns the stale
   pre-write value, and a search/index read may lag behind the write. Picking
   the wrong verification channel produces *false* failure verdicts.

Real case (DMTools/Jira SM pipeline): `jira_move_to_status({statusName:'Backlog'})`
silently no-op'd because the project's Simplified workflow had no `Backlog`
status. The script logged "moved to Backlog" and returned success for 24h+ while
the ticket never left `Bug To Fix`, so no downstream agents were ever dispatched.

## Solution

### Diagnose — prove the state change didn't persist; don't trust logs

- **Compare two consecutive runs** (CI runs, cron ticks). If run N logs "moved to
  X" and run N+1 still finds the item in the OLD state, the write silently
  no-op'd. This is the single most decisive signal.
- **Tally the actual side-effecting calls**:
  `grep -oE "Calling tool [a-z_]+" log | sort | uniq -c`. A *missing* call (e.g.
  zero `trigger_workflow`) localizes the gap in seconds.
- **Check log adjacency**: is the "success" line temporally next to the mutation,
  or does it actually belong to a later request? Timestamps disambiguate.
- **Check the environment's actual schema/workflow** (the set of valid target
  states). A target that's valid in one project/env may not exist in another.

### Harden — make the write unable to fail silently

- After mutating, **VERIFY against fresh ground truth** — a query that bypasses
  the read cache (e.g. JQL / `SELECT … WHERE status = X`), **not** a cached
  get-by-id. Caveats: cached get = *stale*; indexed search = *possible lag* —
  pick the channel that reflects the write, and prefer a positive check ("is it
  now in X?").
- Provide a **fallback** target when the primary may be invalid for this env.
- On **unconfirmed** write: do NOT report success. **Alert once** (idempotent via
  a marker label/flag) and let the next cycle retry. Never park-with-spam and
  never loop-with-false-success.

## Example

```js
// BAD: silent no-op, false success
jira_move_to_status({ key, statusName: 'Backlog' });   // no-ops if status absent
return { success: true };                               // lies, loops forever

// GOOD: move, verify via FRESH query (not a cached get), fall back, react
function moveVerified(key, target, fallback) {
  for (const s of [target, fallback].filter(Boolean)) {
    move(key, s);
    // search/JQL reflects server truth; get-by-id may be cached & stale
    if (searchByQuery(`key=${key} AND status="${s}"`).length) return { moved: true, via: s };
  }
  return { moved: false };   // caller: alert ONCE (idempotent flag) + retry, no false success
}
```

Diagnostic one-liner when "the job passed but nothing happened":
```bash
gh run view --job=<id> --repo <r> --log \
  | grep -oE "Calling tool [a-z_]+" | sort | uniq -c   # is the mutating call even there?
```

## When to Use

- A scheduled/CI job "passes" but a downstream effect never happens.
- Debugging "why didn't X trigger" / "why is this item stuck".
- Writing any verify-after-write: a state transition, status update, or
  idempotent reconcile loop — especially against an SDK/API that **caches reads**
  or **no-ops on invalid requests** instead of throwing.

## Related
- Project gotchas (DMTools/Jira specifics): see project memory
  `dmtools-agents-submodule-and-status-gotcha`.
