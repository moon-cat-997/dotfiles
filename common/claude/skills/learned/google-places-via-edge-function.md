# Call Google Places from a Server-Side Edge Function, Not a Bundled Key

**Extracted:** 2026-06-29
**Context:** Adding Google Places (or any Google Maps Platform REST API) to an
Expo / React Native / SPA app that already has `EXPO_PUBLIC_GOOGLE_MAPS_*` keys.

## Problem
The obvious move is to call Google Places directly from the client with an
`EXPO_PUBLIC_GOOGLE_*` key. Two things break that:
1. **`EXPO_PUBLIC_*` keys ship in the app bundle** — trivially scraped → billing
   abuse. A Places key in the client is a liability.
2. **Platform-restricted Maps keys (Android app / iOS bundle restrictions) reject
   raw REST calls.** The Maps SDK sends `X-Android-Package` / cert headers the
   key checks; a plain `fetch()` does not, so the Places REST endpoint returns
   `REQUEST_DENIED`.

## Solution
Put the call behind a **server-side edge function** with the key as a **secret**:
- Edge function (e.g. Supabase `verify_jwt=true`) reads `GOOGLE_PLACES_KEY` from
  the environment (never bundled), calls Places API (New)
  `POST places:searchNearby` with the `X-Goog-Api-Key` + required
  `X-Goog-FieldMask` headers, normalises the result, returns it.
- Client adapter calls the edge function (`functions.invoke`) — no key client-side.
- **Degrade gracefully:** no key / error → return `[]` so the UI shows its empty
  state instead of crashing. The feature can ship dormant and "light up" once the
  key + billing are configured, with zero code change.

## Key setup gotchas
- Enable **"Places API (New)"** (not the legacy "Places API") + **billing**.
- The key used server-side should have **Application restrictions: None**,
  **API restrictions: Places API (New)**.
- Places API (New) **requires** an `X-Goog-FieldMask` header; request only the
  fields you render (extra fields can bump the billing SKU). `parkingOptions`
  (free/paid · lot/garage/street/valet) is sparsely populated — default
  unclassified results sensibly.

## When to Use
Any time you're about to call a Google Maps Platform REST API (Places, Geocoding,
Routes) from app code with an `EXPO_PUBLIC_*`/public key. Route it through a
server-side function with a secret instead.
