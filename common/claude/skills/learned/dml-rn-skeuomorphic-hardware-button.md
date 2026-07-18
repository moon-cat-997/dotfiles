# Skeuomorphic Hardware Button (Fire-Trigger) in React Native

**Extracted:** 2026-07-18
**Context:** Building a "physical console" push-button (fire trigger, shutter, arm switch, big red button) in React Native / Expo — real depth and material without images or SVG. Distilled from the game-points-count `DmkFireButton` redesign (verified on-device, both themes, adversarially reviewed).

## Problem

A flat icon button cannot carry "this is THE dramatic action" weight. Naive skeuomorphism fails in predictable ways: gloss that reads as a sticker, gradients that gray out on Android, animated Pressables that lose their chrome, disabled states that just dim.

## Solution

### 1. Anatomy — three concentric circles (fixed sizes per size-variant)

```
bezel (mount)  >  well (recess)  >  cap (vivid dome)
```

```tsx
const SIZES = {
  sm: { bezel: 44, well: 36, cap: 28, glyph: 15, travel: 2 },
  md: { bezel: 60, well: 50, cap: 40, glyph: 20, travel: 3 },
};
```

- **Bezel**: raised-surface token fill, 1px strong border, level-1 shadow. The machined mount.
- **Well**: sunken-surface token fill, hairline border. The recess that makes the cap read "mounted into the console".
- **Cap**: the app's ONE deliberately vivid fill + its own small shadow (dome pops out of the well).

Structure: plain `Pressable` (bezel, static styles) > `View` (well) > `Animated.View` (cap) > sheen + glyph.

### 2. Material rendering (no images)

- **Rim**: `borderWidth: 1, borderColor: "rgba(0,0,0,0.28)"` on the cap — the turned dark edge.
- **Sheen**: `expo-linear-gradient` vertical fade covering the top ~60% of the cap, clipped to the dome by the cap's `overflow: "hidden"` + pill radius:
  ```tsx
  <LinearGradient
    pointerEvents="none"
    colors={["rgba(255,255,255,0.20)", "rgba(255,255,255,0)"]}
    style={{ position: "absolute", top: 0, left: 0, right: 0, height: cap * 0.6 }}
  />
  ```
- Keep material constants (gloss/rim/press-scale) in the **theme tokens file**, not the component — scheme-invariant "physical light" values, same standing as elevation's fixed shadowColor.

### 3. Press mechanics (reanimated)

- Down-stroke: `withTiming(1, { duration: ~120ms, easing: Easing.out(Easing.quad) })` — a quick mechanical throw.
- Up-stroke: `withSpring(0, pressSpring)` — return spring.
- Cap animatedStyle: `translateY: depress * travel` + `scale: 1 - depress * 0.05`.
- Reduced motion: snap values instantly (no animation), same states.
- **Haptic on press-IN** (Medium impact "arm click"), so the trigger clunks the moment the finger commits — distinct from the heavier confirm haptic later in the flow.

### 4. States

- **Disabled = unpowered, not dimmed**: swap cap fill to a neutral token + flatten its shadow to level0. The mount stays installed; the trigger has no charge. Never `opacity: 0.4` the whole thing.
- Glyph: FILLED icons only — outlines read as wireframe, not printed hardware iconography. Abstract impact glyphs (octagram burst) beat literal ones at small sizes.

### 5. Color

- If the app's semantic `danger` is deliberately calm chrome, the cap needs its **own vivid token** (one sanctioned loud fill) matched to the app's most saturated accent family — otherwise the cap reads pastel/washed next to them. Don't juice `danger` itself (wide blast radius).
- Contrast: glyph-on-cap needs WCAG 1.4.11's 3:1 graphical floor — compute it against the **sheen-composited** color (base + white overlay), not the raw fill.

## Pitfalls (each one bit during the build)

1. **Gloss pill = sticker.** A small centered translucent pill on the cap reads as "a pink rectangle lying on the button". The sheen must span the full cap width and FADE (gradient), clipped by the cap's circle.
2. **Never fade to `transparent`.** Android interpolates `#00000000` through gray, muddying the fill. Fade to the same color at zero alpha: `rgba(255,255,255,0)`.
3. **Never `Animated.createAnimatedComponent(Pressable)` with conditional chrome** (RN-web chrome-loss class). Plain Pressable shell, all animation on an inner plain `Animated.View`.
4. **`overflow: "hidden"` on the cap is safe with Android `elevation`** — elevation shadows draw outside the outline; only children are clipped.
5. **Icon family**: Ionicons has no swords/crosshairs/burst vocabulary — `MaterialCommunityIcons` (same `@expo/vector-icons` package, zero new deps) has `octagram`, `sword-cross`, `crosshairs`, `shuriken`, `star-four-points`. Verify names against the glyphmap JSON before offering them.
6. **`star-four-points` caveat**: the 4-point sparkle now reads "AI feature" — flag the association before picking it.

## When to Use

Any RN/Expo control that should feel like physical hardware: fire/attack triggers, camera shutters, record/arm buttons, emergency actions. Reference-mine Mobbin for the "big red hardware button" family first ((Not Boring) Camera shutter, SOS/record buttons) — the bezel/well/cap anatomy above matches how the best of them are drawn.
