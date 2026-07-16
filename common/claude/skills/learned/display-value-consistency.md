# Display Value Must Match Computed Value

**Extracted:** 2026-04-05
**Context:** UI components with two related fields (raw vs processed, input vs output)

## Problem
When two related numeric fields exist (e.g. `odds` vs `effective_odds`, `price` vs
`discounted_price`), it's easy to display one and compute with the other.
The user sees X, but the system calculates from Y — a silent inconsistency.

Found in: BetSlip showed `outcome.odds` badge but payout = `stake * outcome.effective_odds`.

## Solution
The prominently displayed value MUST be the one used in calculations.
If a "raw" value also needs to be visible, show it dimmed/secondary.

## Example
// WRONG: display raw, compute effective
<Badge>{outcome.odds}</Badge>           // shows 1.90
payout = stake * outcome.effective_odds  // computes from 1.80

// CORRECT: display effective (what user gets)
<Badge>{outcome.effective_odds}</Badge>  // shows 1.80
payout = stake * outcome.effective_odds  // consistent

## When to Use
When reviewing any component that displays a numeric value AND uses it in a formula.
Audit: grep for all `.toFixed(2)` displays and trace which field feeds downstream calculations.
