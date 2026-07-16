# Reserve a fixed slot for an async indicator so adjacent text doesn't shift

**Extracted:** 2026-06-02
**Context:** A spinner / badge / "updating" indicator that appears next to a live value while data refetches. Hit in polybet's BetSlip where the "To win" amount jumped each quote poll.

## Problem
Rendering a loading indicator inline next to a value (`{value}{isFetching && <Spinner/>}`) changes the element's width when the indicator toggles. Inside a flex row with `justify-between` (or right-aligned text), the value visibly "jumps" sideways every refetch cycle — janky, especially on a fast polling interval.

## Solution
Give the indicator a **fixed-width slot that is always present** (occupied or empty), and keep the value in its own element. The slot reserves the space whether or not the indicator is visible, so the value's position never changes. Put the slot on the side the value is anchored *away from* (e.g. for a right-anchored number, slot on its left).

## Example
```tsx
// ❌ Spinner widens the span → number shifts on every refetch
<span className="flex items-center gap-2 ... justify-...">
  ${value.toFixed(2)}
  {isFetching && <Spinner size="sm" />}
</span>

// ✅ Fixed-width slot reserved on the left; number stays put
<span className="flex items-center gap-2 ...">
  <span aria-hidden className="inline-flex w-4 shrink-0 justify-center">
    {isFetching ? <Spinner size="sm" /> : null}
  </span>
  <span>${value.toFixed(2)}</span>
</span>
```

## When to Use
Any value that updates via polling/refetch and shows a transient spinner/indicator beside it (prices, quotes, live totals, "saving…" states). If a number "jumps" when its spinner appears/disappears, reserve a fixed slot instead of conditionally rendering inline. `aria-hidden` on the decorative slot keeps it out of the a11y tree.
