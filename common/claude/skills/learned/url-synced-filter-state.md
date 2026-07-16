# URL-synced filter state (React Router)

**Extracted:** 2026-05-19
**Context:** React app that needs to persist a structured filter object (board filters, search refinements, table queries) so reload/share/back work without local state loss.

## Problem

A filter panel typically holds a non-trivial object: several enum-valued selects, free-text search, date ranges, boolean flags. Keeping it in `useState` means:

- Reloading the page wipes selections.
- Users can't share a filtered view by copying the URL.
- "Back" doesn't restore the previous filter.

Naive solutions over-engineer it: separate query params per field with bespoke parsing, manual `pushState`, or a state library + a sync effect that creates loops.

## Solution

A small hook that exposes the same shape as `useState` (`[value, setValue]`) but stores the object in URL search params via `react-router-dom`'s `useSearchParams`. Drop-in replacement at the call site.

Key design choices:

1. **Single mapping table** from field name → short URL key (`fStatus`, `fQ`, `fFrom`, …). Short keys keep multi-filter URLs readable.
2. **Defaults are not serialised.** If a field equals its default, the key is `delete`d from the URL — URL stays clean when filters are at rest.
3. **Boolean serialiser** writes `"1"` for true, omits the key for false. Avoids `?flag=false` URLs.
4. **Setter accepts value or updater fn**, just like `useState`, so existing call sites (`onFiltersChange={...}`, `set(prev => ...)`) keep working without changes.
5. **Caller's update is composed against the *current URL state*** inside the setter (not a stale closure). Critical when multiple filters change in quick succession.
6. **Non-filter query params are preserved.** The setter constructs the next `URLSearchParams` from the previous, then mutates only the filter keys. A `?taskId=...` deep-link param survives any filter change.
7. **`replace: true`** on `setSearchParams` — every keystroke shouldn't add to browser history.
8. **`useMemo` keyed by `searchParams.toString()`**, not the `searchParams` identity. Identity changes every render in React Router v6; the string is the actual source of truth.

## Example

```jsx
// useUrlTaskFilters.jsx
import { useCallback, useMemo } from "react";
import { useSearchParams } from "react-router-dom";

export const FILTER_DEFAULTS = {
  status: "all",
  assignee: "all",
  startDate: "",
  endDate: "",
  search: "",
  rejected: false,
};

const URL_KEY = {
  status: "fStatus",
  assignee: "fAssignee",
  startDate: "fFrom",
  endDate: "fTo",
  search: "fQ",
  rejected: "fRej",
};

const BOOL_FIELDS = new Set(["rejected"]);

function parseValue(field, raw) {
  if (raw == null) return FILTER_DEFAULTS[field];
  if (BOOL_FIELDS.has(field)) return raw === "1" || raw === "true";
  return raw;
}

function serializeValue(field, value) {
  if (BOOL_FIELDS.has(field)) return value ? "1" : "";
  return value ?? "";
}

function isDefault(field, value) {
  const def = FILTER_DEFAULTS[field];
  if (BOOL_FIELDS.has(field)) return !value;
  return (value ?? "") === (def ?? "");
}

export function useUrlTaskFilters() {
  const [searchParams, setSearchParams] = useSearchParams();

  const filters = useMemo(() => {
    const next = { ...FILTER_DEFAULTS };
    for (const field of Object.keys(URL_KEY)) {
      next[field] = parseValue(field, searchParams.get(URL_KEY[field]));
    }
    return next;
  }, [searchParams.toString()]); // eslint-disable-line react-hooks/exhaustive-deps

  const setFilters = useCallback((updater) => {
    setSearchParams((prev) => {
      const next = new URLSearchParams(prev);
      const current = { ...FILTER_DEFAULTS };
      for (const field of Object.keys(URL_KEY)) {
        current[field] = parseValue(field, next.get(URL_KEY[field]));
      }
      const incoming = typeof updater === "function" ? updater(current) : updater;
      for (const field of Object.keys(URL_KEY)) {
        const value = incoming?.[field];
        if (isDefault(field, value)) {
          next.delete(URL_KEY[field]);
        } else {
          next.set(URL_KEY[field], serializeValue(field, value));
        }
      }
      return next;
    }, { replace: true });
  }, [setSearchParams]);

  return [filters, setFilters];
}
```

Call site stays as a `useState` replacement:

```jsx
// before
const [filters, setFilters] = useState(FILTER_DEFAULTS);

// after — same destructuring, same setter signature, same consumer code
const [filters, setFilters] = useUrlTaskFilters();
```

## When to Use

Reach for this skill when:

- A page has a filter/search panel with **more than two fields** (one or two query params don't justify the abstraction).
- Users would benefit from **shareable URLs** (board filters, table queries, dashboard views).
- The app uses `react-router-dom` v6 (this hook depends on `useSearchParams`).
- You're tempted to write a `useEffect` that syncs `useState` to `searchParams`. That breaks because it creates loops or stale reads; use this hook instead.

Adapt by:

- Editing `FILTER_DEFAULTS` and `URL_KEY` for the project's fields.
- Adding entries to `BOOL_FIELDS` for boolean toggles.
- Extending the serialiser (`parseValue` / `serializeValue`) for arrays (join/split on comma) or numbers (Number(raw)).

Avoid this skill when:

- Filter state should be **per-tab and not shared** (e.g. private user preferences) — store in `localStorage` instead.
- Filter values are sensitive (exposing them in URLs leaks data).
- The app uses Next.js App Router or TanStack Router; use their router-native equivalents (`useSearchParams` from `next/navigation`, etc).
