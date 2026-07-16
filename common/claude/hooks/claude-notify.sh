#!/usr/bin/env bash
# Desktop notification for Claude Code (GNOME / notify-send).
# Usage (in settings.json hook command):
#   "$HOME/.claude/hooks/claude-notify.sh" stop
#   "$HOME/.claude/hooks/claude-notify.sh" attention
#
# Reads the hook JSON payload from stdin and shows:
#   title: Claude code - work finished | needs your attention
#   body : dir: ~/<cwd>
#          <one-sentence summary>
# plus a sound cue. Returns 0 and writes nothing to stdout.
set -uo pipefail

mode="${1:-stop}"
raw="$(cat)"

# Working directory: prefer payload .cwd, then env, then $PWD.
cwd="$(printf '%s' "$raw" | jq -r '.cwd // empty' 2>/dev/null)"
[ -z "$cwd" ] && cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
# Collapse $HOME to ~ for a shorter display path.
case "$cwd" in
  "$HOME"*) disp="~${cwd#"$HOME"}" ;;
  *)        disp="$cwd" ;;
esac
# Project name = last path segment, appended to the title.
proj="${cwd##*/}"

if [ "$mode" = "attention" ]; then
  title="Claude code - needs your attention - ${proj}"
  detail="$(printf '%s' "$raw" | jq -r '.message // empty' 2>/dev/null)"
  [ -z "$detail" ] && detail="Claude needs your input"
  sound="/usr/share/sounds/freedesktop/stereo/message.oga"
else
  title="Claude code - work finished - ${proj}"
  msg="$(printf '%s' "$raw" | jq -r '.last_assistant_message // empty' 2>/dev/null)"
  # First sentence (or first non-empty line), capped at 150 chars.
  detail="$(printf '%s' "$msg" \
    | tr '\n' ' ' \
    | sed -E 's/^[[:space:]]+//' \
    | grep -oE '^[^.!?]+[.!?]?' \
    | head -c 150)"
  [ -z "$detail" ] && detail="Done"
  sound="/usr/share/sounds/freedesktop/stereo/complete.oga"
fi

body="${disp}
${detail}"

# Collapse repeats: a stable per-project+mode tag makes GNOME replace the
# previous toast with the same tag instead of stacking a new one. Claude Code
# can fire the Notification event several times during one wait (permission
# prompt + idle reminder), so without this they pile up in the tray.
tag="claude-notify:${mode}:${proj}"
notify-send -h "string:x-canonical-private-synchronous:${tag}" "$title" "$body"
# Play sound in background so it never blocks the hook.
{ [ -r "$sound" ] && paplay "$sound" >/dev/null 2>&1; } &

exit 0
