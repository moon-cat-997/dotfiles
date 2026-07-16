---
name: api-silent-param-ignore
description: "External APIs may silently ignore unknown query params, returning default data instead of errors"
user-invocable: false
origin: auto-extracted
---

# API Silent Parameter Ignore

**Extracted:** 2026-04-05
**Context:** Debugging data that appears correct but updates the wrong records

## Problem
External APIs may silently ignore unrecognized query parameters and return
default/unfiltered results instead of an error. Code that blindly takes
`response[0]` then processes the wrong record — and reports success.

Symptoms:
- API returns 200, response has data, no errors
- But the data belongs to a different record than requested
- DB writes succeed but update the wrong row
- Bugs are invisible until you compare returned IDs to requested IDs

## Solution
1. **Always verify the docs for exact param names** (e.g. `condition_ids` vs `conditionId`)
2. **Assert the response matches the request** — after fetching, verify the returned
   record's ID matches what you asked for:
   ```typescript
   const items = await fetchJson(`${API}/items?id=${requestedId}`);
   const match = items.find(item => item.id === requestedId);
   if (!match) throw new Error(`API returned ${items.length} items but none matched ${requestedId}`);
   ```
3. **Don't blindly trust `[0]`** — even when the API "should" return one result

## When to Use
- Integrating with any external REST API
- Debugging "successful" operations that don't produce expected side effects
- Data appears stale despite API returning 200 with data
