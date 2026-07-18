# Remote On-Device Design Iteration (adb + Metro + screenshots)

**Extracted:** 2026-07-18
**Context:** Iterating visual design collaboratively with a user who watches a physical Android device (or screenshots) remotely, while Claude drives via adb. Distilled from the game-points-count fire-button redesign session (glyph + color + gloss converged in 3 rounds).

## Problem

Design decisions ("which icon", "is this saturated enough", "does the gloss read right") can't be made from code or ASCII mockups. The user must see REAL rendered pixels — and the loop must be fast enough to iterate several times in one session.

## Solution — the candidate-lineup loop

1. **Render candidates in the app's UI-kit/gallery screen** via a clearly-marked temp block (`{/* TEMP ... remove before commit */}`), each candidate labeled `A · name`, `B · name`... Metro fast-refresh makes each edit visible in seconds — no rebuild.
2. **Screenshot** (`adb exec-out screencap -p > file.png`), then **crop + zoom** the relevant region for the user (full screenshots hide the detail being judged):
   ```bash
   ffmpeg -y -i shot.png -vf "crop=W:H:X:Y,scale=2*W:2*H:flags=neighbor" zoom.png
   ```
   `flags=neighbor` keeps pixels crisp when zooming UI.
3. **Send the image, then ask** with lettered options matching the image labels. Present an honest recommendation with the trade-off named (e.g. "B is prettiest but reads as the AI-sparkle").
4. Apply the pick, **delete the temp block before commit**, re-run gates.
5. For a binary variant (e.g. gloss vs matte): flip a token value, screenshot, revert, and send an `hstack`/`vstack` composite:
   ```bash
   ffmpeg -y -i a.png -i b.png -filter_complex hstack compare.png
   ```

## Verifying motion without eyes on the device

Screen-record during the interaction, then pixel-diff frames to prove the animation timeline:

```bash
adb shell "screenrecord --time-limit 5 /sdcard/x.mp4" & sleep 1.2
adb shell input swipe X Y X Y 2500   # long-press = swipe to same point
adb pull /sdcard/x.mp4 .
ffmpeg -i x.mp4 -vf "fps=8,crop=..." f-%02d.png
# PIL: ImageChops.difference vs an idle frame → meandiff per frame
```

A press animation shows as: zero diff (idle) → one transition frame (the ~120ms stroke) → constant nonzero diff (held state) → big diff (release/next screen). Note: `screenrecord` may fall back to 720x1280 — rescale crop coordinates from the 1080-wide screenshots.

## Gotchas

- **`pkill -f "expo start"` suicide**: if the SAME compound command later contains the literal text `npx expo start`, pkill matches the invoking shell's own command line and kills it (exit 144, no output). Keep the kill and the start in separate Bash calls.
- **Back-press at the app's root route exits Expo Go** — subsequent scripted taps land on the Android launcher. After any `keyevent 4` navigation, verify the next screenshot actually shows the app before continuing; relaunch with the `exp://127.0.0.1:8081` deep link if not.
- **Fresh-bundle discipline** (from prior sessions): verify a code change with `expo start --clear` + `adb shell am force-stop host.exp.exponent` + deep-link relaunch, or you "verify" a stale bundle.
- **Screenshot coordinate mapping**: screenshots may be displayed scaled (e.g. 900x2000 for a 1080x2400 screen) — multiply tap coordinates by the stated factor.
- **Scrolling to a gallery section**: swipe distances drift as temp blocks change layout height; screenshot after each scroll instead of assuming position.

## When to Use

Any session where visual design choices are being made collaboratively on a real device: icon/glyph selection, color tuning, material/gloss treatments, animation feel. Also applies (with different capture tooling) to web: same lineup-label-screenshot-pick loop.
