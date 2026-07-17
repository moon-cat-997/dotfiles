#!/bin/bash
#
# claude-sync — (re)apply the portable Claude Code config on this machine.
#
# Idempotent and safe to run anytime:
#   1. symlinks the configs from common/claude/ into ~/.claude
#      (repairing drift if Claude Code replaced a symlink with a plain file)
#   2. registers the user-scope MCP servers from mcp-servers.conf
#      (no login — each server OAuths lazily on first use in a session)
#
# Called by install.sh; also linked into ~/bin as `claude-sync`.

set -e

CLAUDE_SRC=~/dotfiles/common/claude

echo "- Syncing Claude Code configs..."

# 1. Link configs (settings, statusline, global CLAUDE.md, hooks/scripts,
#    skills, commands, rules) into ~/.claude.
# -n: replace an existing dir symlink instead of descending into it.
# A pre-existing REAL file/dir (fresh machine where Claude Code ran first)
# is backed up once as *.pre-dotfiles rather than clobbered — except when a
# symlink existed before and got replaced by a plain file (Claude Code
# rewriting settings.json): that's drift, backed up with a timestamp so the
# user can diff it into the repo.
mkdir -p ~/.claude
for item in settings.json CLAUDE.md statusline-command.sh hooks scripts skills commands rules; do
  src=$CLAUDE_SRC/$item
  dst=~/.claude/$item
  [ -e "$src" ] || continue
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    if [ -f "$dst" ] && [ -f "$src" ] && ! cmp -s "$dst" "$src"; then
      backup="$dst.drift-$(date +%Y%m%d-%H%M%S)"
      mv "$dst" "$backup"
      echo "  ⚠ $item was a plain file differing from the repo — saved as $(basename "$backup")."
      echo "    Diff it against $src and commit anything worth keeping."
    else
      mv "$dst" "$dst.pre-dotfiles"
      echo "  (backed up existing $item → $item.pre-dotfiles)"
    fi
  fi
  ln -sfn "$src" "$dst"
  echo "  ✔ Linked $item"
done

# 2. Register user-scope MCP servers declared in mcp-servers.conf.
# `claude mcp add` only writes config — no login here; OAuth happens on
# first use inside Claude Code.
if ! command -v claude >/dev/null 2>&1; then
  echo "  ⚠ claude CLI not on PATH — skipped MCP server registration."
  echo "    Re-run claude-sync after installing Claude Code."
else
  echo "- Registering user-scope MCP servers..."
  while read -r name url _; do
    case "$name" in ''|\#*) continue ;; esac
    if claude mcp get "$name" >/dev/null 2>&1; then
      echo "  ✔ $name already registered"
    else
      claude mcp add --scope user --transport http "$name" "$url" >/dev/null
      echo "  ✔ Added $name ($url)"
    fi
  done < "$CLAUDE_SRC/mcp-servers.conf"
fi

# 3. Fresh-machine hint (auth is per-machine by design and never synced).
# Linux only — on macOS credentials live in the Keychain, not this file.
if [ "$(uname -s)" = "Linux" ] && [ ! -e ~/.claude/.credentials.json ]; then
  echo "  ℹ No Claude credentials found — run \`claude\` once to log in (MCP servers authorize themselves on first use)."
fi

echo "✅ Claude Code config synced."
