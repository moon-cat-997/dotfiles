#!/bin/bash
#
# Entry point. Three phases, in order:
#   1. shared    — links that are identical on every OS
#   2. platform  — platform/<os>/setup.sh owns packages and OS-specific wiring
#   3. sync      — the cross-platform "buttons": agent CLIs, then their configs
#
# Anything OS-specific belongs in platform/, not here. Paths are ~-relative
# throughout, so the username does not matter; the repo location (~/dotfiles)
# is still assumed. See CLAUDE.md.

set -e

echo "- Installing dotfiles..."

# Detect OS
OS="$(uname -s)"
echo "- Detected OS: $OS"

# Ensure ~/bin exists
mkdir -p ~/bin

# ~/.ssh may not exist on a fresh machine — create it before linking ssh_config,
# otherwise `ln -sf ... ~/.ssh/config` fails and set -e aborts the install.
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# ── 1. Shared ────────────────────────────────────────────────────────────────

# Link config files
#   git/ssh configs live under utilities/git-hat/config-files/
#   zshrc lives under common/
#   gitconfig/ssh_config are static bases that `include` the generated files;
#   per-persona identities are produced by `git-hat sync` (see below).
GP_CONFIG=~/dotfiles/utilities/git-hat/config-files
ln -sf "$GP_CONFIG/gitconfig"  ~/.gitconfig
ln -sf "$GP_CONFIG/ssh_config" ~/.ssh/config
ln -sf ~/dotfiles/common/zshrc ~/.zshrc

# Cross-platform helper scripts → ~/bin.
# (the dir may be absent — git doesn't track empty directories)
# OS-specific scripts are NOT linked here: each platform/<os>/setup.sh links its
# own bin/, so a Mac never gets pacman-based tools like update-system on PATH.
echo "- Linking common scripts..."
for script in ~/dotfiles/git-scripts/*.sh; do
  [ -e "$script" ] || continue
  chmod +x "$script"
  name=$(basename "$script" .sh)
  ln -sf "$script" "$HOME/bin/$name"
  echo "  ✔ Linked $name"
done

# Link the sync buttons (both are also invoked at the end of this script)
echo "- Linking sync buttons..."
chmod +x ~/dotfiles/common/claude/claude-sync.sh ~/dotfiles/common/codex/codex-sync.sh
ln -sf ~/dotfiles/common/claude/claude-sync.sh "$HOME/bin/claude-sync"
ln -sf ~/dotfiles/common/codex/codex-sync.sh   "$HOME/bin/codex-sync"
echo "  ✔ Linked claude-sync, codex-sync"

# Link git-hat utility (usable as `git-hat`, `git hat`, or `hat`)
echo "- Linking git-hat..."
chmod +x ~/dotfiles/utilities/git-hat/git-hat
ln -sf ~/dotfiles/utilities/git-hat/git-hat "$HOME/bin/git-hat"
ln -sf ~/dotfiles/utilities/git-hat/git-hat "$HOME/bin/hat"
echo "  ✔ Linked git-hat, hat"

# Generate ssh/git identity configs from personas/ (source of truth) into generated/
echo "- Generating git-hat configs..."
~/dotfiles/utilities/git-hat/git-hat sync

# ── 2. Platform ──────────────────────────────────────────────────────────────

case "$OS" in
  Linux)
    echo "🐧 Running Linux setup..."
    bash ~/dotfiles/platform/linux/setup.sh
    ;;
  Darwin)
    echo "🍎 Running macOS setup..."
    bash ~/dotfiles/platform/macos/setup.sh
    ;;
  *)
    echo "❌ Unsupported OS: $OS"
    exit 1
    ;;
esac

# ── 3. Sync ──────────────────────────────────────────────────────────────────

# Agent CLIs (claude, codex). After the platform setup so curl/brew exist,
# before the sync buttons so claude-sync can register MCP servers.
bash ~/dotfiles/common/install-agents.sh

# Sync Claude Code configs (symlinks + user-scope MCP servers).
bash ~/dotfiles/common/claude/claude-sync.sh

# Sync Codex configs (global instructions, selected skills, managed config baseline).
bash ~/dotfiles/common/codex/codex-sync.sh

echo "✅ Done!"
