# Calibrate Fuzzy/Heuristic Matchers Against Real Data (Don't Guess Thresholds)

**Extracted:** 2026-05-26
**Context:** Building a deterministic matcher/classifier with tunable thresholds (fuzzy string match, similarity ratio, confidence cutoff) — typically to replace or back up an LLM that previously did the understanding "for free."

## Problem
You write a fuzzy matcher (e.g. free-text product name → catalog entry) and pick thresholds by intuition. Those numbers are meaningless until tested against the **real** data: the actual names have shared prefixes, locale punctuation, plurals, and length distributions you didn't anticipate. Guessed thresholds ship false matches (wrong product) or false rejects (defers when it shouldn't). Synthetic test data you invent rarely reflects the real ambiguity shape.

## Solution
1. **Pull the real data, read-only.** If there's an MCP server / API / DB for the live data, query the actual entries (e.g. `mcp__base44__query_entities(appId, "Product")`). Beware identifier confusion — verify you're hitting the right app/table (in this session the screenshot URL's app id was a *different* app than the one holding the catalog).
2. **Build a representative corpus** of `(query → expected)` cases over the real entries: exact, abbreviation/substring, word-in-a-sentence, locale typos, category words (should be *ambiguous* → defer), and out-of-vocabulary (should be no-match → defer).
3. **Run, find mismatches, fix root cause** (often normalization or a missing match stage), iterate to 0 mismatches.
4. **Lock it with a real-data regression test** snapshotting the catalog + the resolutions, dated, with a note to re-verify if the data changes.

### Matcher design that fell out of calibration
Layered, most-strict-first, with an **ambiguity guard** so a vague query never silently picks one of several:
1. exact (after normalization)
2. containment either way (`q in name` or `name in q`)
3. query-token containment (item word embedded in a sentence) — tokens ≥3 chars to skip stop-words
4. fuzzy ratio (`difflib`), scored against the whole name **and each word** (catches a typo in one word of a multi-word name), with a runner-up margin guard

Normalization gotcha: locale punctuation. Hebrew geresh / ASCII apostrophe inside a word (`פוקצ'ה`) must be **stripped/joined** (→ `פוקצה`), not replaced with a space (which splits the word and breaks matching). Strip in-word apostrophes first, then turn remaining punctuation into spaces.

Routing gotcha: feed the matcher the **full** candidate set (incl. out-of-stock/inactive) so a category word shared by siblings reads as *ambiguous* and defers; enforce availability separately downstream.

## Example
```python
ALL = ["פיצה זוגית","פיצה משפחתית","פסטה אלפרדו","פוקצ'ה","סלט יווני","פסטה בולונז"]
for q, expected in CORPUS:               # exact/substring/token/typo + ambiguous + unknown
    r = match_product(q, ALL)
    assert r.matched == expected         # 0/22 mismatches after tuning
# Then: tests/.../test_<matcher>_real_catalog.py locks the snapshot.
```

## When to Use
- Implementing a fuzzy/heuristic matcher or a confidence cutoff with magic numbers.
- Replacing an LLM's free-text understanding with deterministic code (the LLM hid the matching difficulty).
- Tempted to "set threshold = 0.8 and move on" — pull real data and verify first.
- A matcher works on toy examples but you haven't seen it against production names/labels.
