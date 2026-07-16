---
name: expo-router-tab-folder-wiring
description: Expo Router v6 — tab pointing to a folder with index.tsx + sub-screens needs an explicit Stack `_layout.tsx` with `unstable_settings.initialRouteName` AND `<Stack initialRouteName>`, otherwise navigating to that tab silently renders the first Tabs.Screen (usually feed) instead of the folder's index.
---

# Expo Router: Tab-folder needs Stack with explicit initialRouteName

**Extracted:** 2026-05-01
**Context:** Expo Router v6 + bottom Tabs, where one or more tabs are folders containing `index.tsx` plus sub-screens (e.g. `app/(buyer)/profile/{index,address,security,transactions}.tsx`).

## Problem

A bottom-tab declared as `<Tabs.Screen name="profile" />` points to a folder. When the user taps that tab, the app **silently renders the first registered Tab.Screen** (typically `feed/index`) instead of `profile/index.tsx`. Other symptoms that confirm the same root cause:

- Tab label falls back to the raw route name (lowercase `profile`) instead of the localized title from `t('common:profile')`.
- URL is correct (`/profile`) but DOM shows `/feed` content.
- Bottom-tab orange "active" highlight may land on the wrong tab.
- Restarting Metro / `--clear` does NOT fix it. (This is the second-most-wasted hour.)

Anti-patterns that look promising but don't work:

- ❌ `<Tabs.Screen name="profile/index" />` — breaks subroute resolution; tab label becomes `profile/index`.
- ❌ Manually registering each subroute as `<Tabs.Screen name="profile/X" options={{ href: null }} />` — verbose, doesn't fix the default route, sub-screens become loose.
- ❌ Adding `redirect` or `initialParams` on the parent Tabs.Screen.

## Root cause

When a tab's `name` resolves to a folder with multiple files and **no `_layout.tsx`** (or a `_layout.tsx` without explicit `initialRouteName`), Expo Router cannot infer which file is the default. It silently falls back to the first sibling Tab.Screen — visually breaking navigation while reporting the URL as if it worked.

## Solution

Add `app/(role)/<tab>/_layout.tsx` with **both** `unstable_settings` and `<Stack initialRouteName>`:

```tsx
// app/(buyer)/profile/_layout.tsx
import React from 'react';
import { Stack } from 'expo-router';

export const unstable_settings = {
  initialRouteName: 'index',
};

export default function ProfileLayout() {
  return (
    <Stack screenOptions={{ headerShown: false }} initialRouteName="index">
      <Stack.Screen name="index" />
      <Stack.Screen name="address" />
      <Stack.Screen name="security" />
      <Stack.Screen name="transactions" />
      {/* …every sub-screen file in the folder */}
    </Stack>
  );
}
```

Both declarations are needed:
- `unstable_settings.initialRouteName` — picked up by Expo's static analysis (build-time)
- `<Stack initialRouteName="index">` — used by react-navigation at runtime

In the parent `(role)/_layout.tsx`, reference the tab as the **folder name only**:

```tsx
<Tabs.Screen name="profile" options={{ title: t('common:profile') }} />
```

## Related: Playwright tests must use group prefixes

Sibling gotcha — when both `app/(buyer)/orders/index.tsx` and `app/(seller)/orders/index.tsx` exist, the URL `/orders` is **ambiguous**. Expo Router web silently picks one (usually `(buyer)` because alphabetic), so seller-role tests opening `/orders` directly will see buyer content.

**Fix in Playwright:** prefix every URL with the group:

```ts
// WRONG — picks buyer's /orders even when logged in as seller
await page.goto('/orders');

// RIGHT — explicit group
await page.goto('/(seller)/orders');
```

In real user flow this isn't an issue because `app/index.tsx` redirects to `/(role)/...` after login, and tab presses dispatch within the active group. The bug only surfaces in tests that bypass tab navigation with `goto()`.

## When to use

Trigger this skill when **any** of the following match:

- A bottom-tab whose `name` is a folder (multiple `*.tsx` files inside) renders the wrong screen
- Tab label shows the raw path string (e.g. `profile`) instead of localized title
- Manual flow works but Playwright `page.goto('/<role>/<screen>')` lands on wrong content
- You're about to add a new tab that's a folder — write the `_layout.tsx` upfront with both declarations

Skip when the tab points to a single file (`feed/index.tsx` only) — Tabs.Screen alone is fine.

## How to apply

1. **Confirm the symptom:** Playwright (or manual) navigation to the broken tab; verify URL is correct but DOM is from another tab.
2. **Check `_layout.tsx`** in the folder. If missing — create. If present — verify `unstable_settings` AND `<Stack initialRouteName>`. Both, not either.
3. **Verify parent layout** uses bare folder name (`name="profile"`, not `name="profile/index"`).
4. **For Playwright tests** that direct-navigate, use group prefixes (`/(role)/screen`).
5. **Don't trust Metro `--clear`** as a fix. If symptom persists after clearing, the layout is the root cause.
