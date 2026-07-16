# react-native-web parity gotchas (Expo web)

**Extracted:** 2026-05-31
**Context:** Expo app rendered via react-native-web. Code works on native but
silently breaks on web. Surfaced in buy-by-power seller lot wizard (Step2Media).

## Problem
Several React Native APIs behave differently or no-op on react-native-web,
producing "works on device, broken in browser" bugs that throw no error.

## Gotchas & fixes

### 1. Alert.alert action buttons are a no-op on web
`Alert.alert(title, msg, [{text, onPress}])` — on RNW the **buttons array and
its `onPress` callbacks are ignored** (only `window.alert(title+msg)` shows).
So confirm dialogs never run their action → "the button does nothing on web".
- 2-arg `Alert.alert(title, body)` DOES show (via window.alert).
- **Fix:** for any confirm-with-action, use a cross-platform modal
  (this project has `@/components/shared/ConfirmModal`), not `Alert.alert`.

### 2. Nested Pressable = invalid <button> in <button> -> taps swallowed
RNW renders `<Pressable accessibilityRole="button">` as `<button>`. Nesting a
Pressable inside another Pressable yields `<button><button>...` (invalid HTML);
the inner tap gets swallowed/mishandled. React warns "button cannot be a
descendant of button".
- **Fix:** make the outer container a plain `<View>` when its children have
  their own pressables; keep only one Pressable level. The browser console's
  nested-button warning is the smoking gun.

### 3. expo-video-thumbnails throws on web
`VideoThumbnails.getThumbnailAsync()` -> `Error: ExpoVideoThumbnails not
supported on Expo Web`. Any thumbnail-based video preview renders nothing on web.
- **Fix:** render the clip itself with `expo-video` `VideoView` (works on web
  via HTMLVideoElement + native) for an inline first-frame preview; keep the
  generated thumbnail only as a native fast-path.

## How to confirm on web
Open the browser console while reproducing: look for React invalid-DOM-nesting
warnings (button-in-button), and check the actual rendered `<img>`/element.
Playwright `browser_console_messages` + a screenshot pinpoint it fast.

## When to Use
Building/debugging Expo UI that also runs on web (react-native-web): confirm
dialogs, photo/media grids with remove/X buttons, nested touchables, or video
thumbnails. If a tap/dialog/preview "works on native but not in the browser",
check these three first.
