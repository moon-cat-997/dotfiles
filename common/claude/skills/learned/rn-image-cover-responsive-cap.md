# RN Image cover-mode crops to background on wide viewports

**Extracted:** 2026-05-03
**Context:** React Native / Expo apps rendered via react-native-web on responsive viewports (mobile + desktop sharing one build).

## Problem

`<Image resizeMode="cover">` with `width: screenWidth` looks fine on mobile but on a wide desktop viewport the container becomes extremely wide-and-short (e.g. 1900×278). With `cover`:

1. Image is scaled to fill width (e.g. 800×533 source scaled to 1900×1267).
2. Then aggressively cropped vertically to the container height.
3. If the source photo has a uniform background (e.g. a red product backdrop), the visible slice ends up being mostly that background — the user sees a solid-colour rectangle and assumes the image is broken.

Same code, same URL, identical-looking failure on desktop, perfect render on mobile in DevTools responsive mode.

## Diagnostic signals

- `curl -I` on the image URL returns **200** with a real `image/jpeg` content-type.
- Network tab in browser also shows the request succeeded.
- The "broken" area is a **uniform colour that matches the photo's background**, not the browser's broken-image icon.
- Resizing the browser window narrower fixes it instantly.

When all three signals are present, it's not a load failure — it's `cover` over-cropping. Don't chase CORS, env vars, or service workers.

## Solution

Cap the container width to a sane "phone-sized" maximum and centre it. `cover` then crops a reasonable slice regardless of viewport.

```tsx
const { width: screenWidth } = useWindowDimensions();
const imageWidth = Math.min(screenWidth - 10, 560);

// styles
imageSection: {
  height: 278,
  width: '100%',
  maxWidth: 560,
  alignSelf: 'center',
  overflow: 'hidden',
},

// JSX
<Image
  source={src}
  style={{ width: imageWidth, height: 278 }}
  resizeMode="cover"
/>
```

The `560` cap is a reasonable phone-frame width for a hero/carousel; pick whatever matches your design.

## Things that DO NOT fix it (and waste time)

- Switching `cover` → `contain` — image disappears entirely on some RN-Web setups, or you get letterbox bars that look like an empty area.
- Wrapping `<Image>` in a `<View>` with explicit width/height + `100%/100%` inside — same cropping math applies.
- Adding `onError` / `onLoad` handlers — they fire `onLoad` because the image really did load.
- Clearing browser cache / hard reset / `expo start --clear` — the bug is layout, not caching.

## When to Use

- RN / Expo screen shipped to web via react-native-web
- Image carousel or hero with a fixed height + dynamic (viewport-derived) width
- User reports "image not showing" but the URL is verifiably reachable
- The rendered area is a solid colour matching the photo's background — that's the giveaway, not a real load failure
