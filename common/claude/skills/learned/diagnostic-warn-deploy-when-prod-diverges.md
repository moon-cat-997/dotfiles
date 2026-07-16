# Diagnostic-warn-and-deploy when local repro works but prod fails

**Extracted:** 2026-05-03
**Context:** A specific code path appears to work locally and in tests, but production logs report failure on the same inputs. Reproducing in dev is impossible because the failure depends on production's network egress, edge cache, region, or runtime version that you can't replicate.

## Problem
You see a production error like `unresolvable_upstream: 3` or `settle failed for X`. You curl the same upstream URL the production server hits, you call the same function with the same payload locally — everything returns the expected good value. But production keeps failing on the same inputs.

Standard local debugging hits a wall because the failure isn't in the code — it's in the data the code receives, and that data only diverges in production. You can't see it because the code only logs `count: N failed` summaries, not the raw payload at the failure boundary.

The trap: you start guessing fixes ("maybe Polymarket returns arrays not strings sometimes", "maybe the threshold is too strict"), apply defensive code, and either mask the real bug or leave it unfixed.

## Solution
Don't guess. Add a **single targeted `logger.warn`** at the exact branch that fails, dumping the raw shape of the suspect data, then ship that diagnostic to production:

```ts
const winnerToken = pickWinningTokenFromGamma(gm);
if (!winnerToken) {
  unresolvable++;
  logger.warn(
    {
      polymarketId: row.polymarket_id,
      // dump every field the picker reads, with type info
      typeofOutcomePrices: typeof gm.outcomePrices,
      rawOutcomePrices:
        typeof gm.outcomePrices === 'string'
          ? gm.outcomePrices
          : JSON.stringify(gm.outcomePrices)?.slice(0, 200),
      typeofClobTokenIds: typeof gm.clobTokenIds,
      rawClobTokenIds:
        typeof gm.clobTokenIds === 'string'
          ? gm.clobTokenIds.slice(0, 120)
          : JSON.stringify(gm.clobTokenIds)?.slice(0, 200),
      tokensLen: Array.isArray(gm.tokens) ? gm.tokens.length : null,
      // also dump every adjacent state field the gate checks
      closed: gm.closed,
      resolved: gm.resolved,
      uma: gm.umaResolutionStatus ?? null,
    },
    'reconcileStrandedBets: unresolvable upstream payload',
  );
  continue;
}
```

Rules of the dump:
- **Log `typeof`** as well as the value. The most common silent diverger is the source returning `array` where you expect `string` (or vice versa).
- **Cap each field** with `.slice(...)` so a runaway giant payload doesn't flood the log pipeline.
- **Dump every field the failing branch reads**, plus adjacent flags that gate it. You only get one cycle, make it count.
- **One `logger.warn` per fail event**, not per call — counters are still useful, the warn supplements them.

Then deploy and **wait for one natural failure** (or provoke one in a controlled way). Do NOT guess at the fix until the warn fires. The dump tells you the actual data shape at the failure boundary, which usually points directly at the cause.

## Provoking a failure when natural ones are too rare
If the failure mode requires a specific upstream state and you don't want to wait days, controlled provocation works — *but tear down on the same path you set up*:

1. Snapshot every column you're going to mutate (target rows, related rows, derived balances/counters).
2. Disable user triggers around the strand-injecting UPDATEs to avoid trigger fight (`ALTER TABLE x DISABLE TRIGGER USER`).
3. Wait for ≤1 worker tick.
4. Read logs.
5. Restore *every* snapshotted value with direct UPDATEs (do NOT call the same business function — it'll fight idempotency invariants you may have broken with the strand).

A common failure mode of provocation tests is: the production code path *did* run, but failed at a different layer than the bug under test (e.g., re-settling an already-paid bet trips a ledger uniqueness trigger that doesn't exist for fresh bets). Recognize this as a *separate finding* and don't conflate it with the original bug.

## When to Use
- Production summary logs say "N failures" without per-failure detail
- Local reproduction with the same inputs returns success
- You suspect upstream API edge-cache jitter, region-specific responses, runtime version differences, or stale data
- You've already verified deployed code matches source (no stale `dist/`, no rollback)
- The fix-by-guessing temptation is strong — push it back, ship the warn first

## When NOT to use
- If you can `repl` into the production runtime directly (just inspect the variable, no code change needed)
- If the failure rate is < 1/day and you need an answer in minutes — go to upstream provider's status page or recent changelog instead
- For fast-iteration bugs where you can roll forward with multiple fix attempts cheaply

## Bonus: leave the warn in place after the fix
A diagnostic warn that fires only on a known-impossible condition is essentially free monitoring. Keep it. When it fires again 6 months later because the upstream provider changed their schema again, you'll thank past-you.
