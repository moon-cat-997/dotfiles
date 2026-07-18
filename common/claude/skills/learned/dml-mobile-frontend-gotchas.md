---
name: dml-mobile-frontend-gotchas
description: Mobile/responsive front-end gotchas and fixes — horizontal scroll that survives an overflow-x guard (fixed/portaled elements), touch-tap stuck focus/hover, swipe-to-dismiss bottom sheets, and how to actually test these (Playwright tap vs click, reproduce geometry, WebKit-from-Blink diagnosis). Use when building or debugging responsive web UI, especially when a fix works in Chrome devtools but not on a real phone.
origin: personal-dm812
---

# Mobile / Responsive Front-End Gotchas

**Extracted:** 2026-06-28
**Context:** Building/debugging responsive web UI (bottom sheets, fixed bars, feed
pills, dense headers). The unifying theme: **a fix that looks correct in Chrome
devtools can still be broken on a real phone (iOS Safari / touch).** Verify on the
real engine and input method, not just Blink + mouse.

---

## 1. Horizontal scroll that survives an `overflow-x` guard = a fixed/portaled element

### Problem
You add `overflow-x: hidden`/`clip` to the root to kill a horizontal scrollbar, but
the page still scrolls sideways on some devices — usually iOS Safari, often only
intermittently. A Chrome DOM audit shows `documentElement.scrollWidth == clientWidth`
(no overflow), so the bug "isn't there" in your dev browser.

Two compounding root causes:
1. **A `position: fixed`/portaled element is wider than the viewport.** Root-level
   `overflow-x` CANNOT clip fixed descendants — their containing block is the
   viewport, not the clipped ancestor. Classic culprit: a toast lib whose mobile CSS
   sets `width:100%` AND a one-sided `left` offset (sonner ≤600px:
   `width:100%; left:16px` → right edge = vw + 16px). It only overflows while mounted
   → intermittent scroll.
2. **`overflow-x: clip` on the root is unreliable in WebKit/iOS** for *scroll
   prevention* (old Safari ignores `clip`; even 16+ may not suppress root scroll). It
   works in Blink — which is why your Chrome audit looks clean.

### Solution
- When scroll survives a root guard, **suspect fixed/portaled widgets first** (toasts,
  drawers, sheets, popovers). Constrain their width: `width: calc(100% - offsets)` or
  `max-width: 100vw`; never pair `width:100%` with a one-sided `left`/`right`.
- Prefer **`overflow-x: hidden` on `html` ONLY** (not `body`): it propagates to the
  viewport so sticky headers still pin, and is reliable in WebKit. `hidden` on `body`
  makes a nested scroll container that BREAKS `position: sticky`; `clip` keeps sticky
  but is unreliable on iOS.
- A root guard is a safety net for *in-flow* overflow only — not a fix for
  fixed-element overflow.

| guard | sticky header | blocks h-scroll |
|---|---|---|
| `clip` html+body | ok | Blink only, NOT iOS |
| **`hidden` html only** | ok | yes, incl. iOS |
| `hidden` html+body | BREAKS | yes |

---

## 2. Touch tap leaves elements stuck in `:focus`/hover state

### Problem
A pill/button that styles itself via `onFocus`/`onMouseEnter` (e.g. a feed outcome
pill that fills solid + shows a % on hover) stays **stuck highlighted** after a touch
tap. On touch a tap both focuses the element AND fires mouse-compat `enter` with no
matching `leave`; nothing blurs it (e.g. closing a sheet by swiping its grab handle
never blurs the trigger button), so the hover/focus visual sticks.

### Solution
On click, **clear the state directly AND blur**:
```jsx
onClick={(e) => {
  doAction(id);
  setHoveredId(null);     // direct clear — covers the mouse-enter-without-leave path
  e.currentTarget.blur(); // drop focus so it can't re-trigger
}}
```
`blur()` alone is insufficient (it only fixes the focus path, not the stuck
mouse-enter). Clear the state explicitly.

---

## 3. Swipe-to-dismiss bottom sheet

### Solution
- Bind the gesture's `pointermove`/`pointerup` listeners on **`window`** (added in the
  grab handle's `pointerdown`, removed on up), NOT `setPointerCapture`. Capture is
  unreliable when the drag handle is a thin bar and across touch/mouse/headless
  drivers; window listeners keep tracking once the finger leaves the handle.
- Drag down past a threshold → `onClose()`; else animate back to `translateY(0)`.
- Put `touch-action: none` on the grab handle so the gesture moves the sheet instead
  of scrolling the page. Add a `@media (prefers-reduced-motion)` path.
- Scope the bottom-sheet treatment (backdrop, grab handle, swipe, slide-up) to a
  single breakpoint that pairs with the desktop "docked column" breakpoint, so there
  is no awkward floating-overlay middle mode: `≤(dock-1)px` = bottom-sheet popup,
  `≥dock px` = docked column. Cap + center the sheet on wide tablets
  (`max-width: 30rem; margin-inline: auto`) so it doesn't stretch edge-to-edge.

---

## Testing these (the part that actually catches the bug)

- **Use the real input method.** Playwright `locator.click()` uses the MOUSE path
  (`mouseenter`, no leave) and *masks/changes* touch-focus bugs. Use `locator.tap()`
  (context `hasTouch: true`) for the real touch path. For swipe, dispatch real
  `PointerEvent`s (`pointerType:'touch'`) — `page.mouse` may not deliver
  `pointermove`/`pointerup` to `window` listeners in headless.
- **Wait out entrance animations before measuring.** Measuring a sheet right after it
  opens catches it mid slide-up (`transform: translateY(100%)`) → grab handle measured
  off-screen, drag targets wrong coords. Wait ~animation duration first.
- **Surface invisible (WebKit-only) overflow from Blink:** temporarily neutralize the
  guard — `de.style.setProperty('overflow-x','visible','important')` — then list
  elements with `rect.right > innerWidth` **excluding** any inside an
  `overflow-x:auto/scroll/clip/hidden` ancestor (intentional carousels). Separately
  list `position:fixed/absolute` elements with `width > innerWidth`. What's left is the
  culprit Safari would scroll.
- **Can't run WebKit locally** (Playwright webkit needs system libs via sudo)?
  **Reproduce the geometry instead**: recreate the third-party element (correct
  `data-*` attrs + CSS custom props) so its bundled stylesheet applies, then read
  `getBoundingClientRect()` to confirm the overflow without a live trigger.
- **Sweep widths around every breakpoint** (e.g. 320/390/768/900/1023/1024/1280),
  asserting `documentElement.scrollWidth - clientWidth == 0`, header
  `scrollWidth == clientWidth`, and content `right ≈ viewport - padding` (a large gap
  = stray empty space / a column not filling).

## Bonus: dense top bars
The biggest density hog in an app header is usually a fixed-width persistent search
input (~12rem). When a top bar is "too dense" at md/lg widths, defer the least
essential chrome to `xl` (`hidden xl:block`): persistent search, username, secondary
labels, count badges. A count badge styled `rounded-full` will become a 2-line circle
when squeezed — add `whitespace-nowrap` so it stays a pill.

## When to Use
- Building or reviewing any responsive web UI (bottom sheets, fixed bars, headers).
- A horizontal scrollbar / drifting fixed bar appears despite an `overflow-x` guard.
- A control stays "stuck" highlighted after a tap; a sheet won't swipe-close.
- A responsive fix works in Chrome devtools but the user still sees it broken on a phone.
- A top bar feels crammed at tablet/small-desktop widths.
