#!/bin/bash

set -e

echo "🔄 Starting full system update..."

# yay is installed by linux-setup.sh (via install.sh)
if ! command -v yay >/dev/null 2>&1; then
  echo "❌ yay is missing — run ~/dotfiles/install.sh first" >&2
  exit 1
fi

# Ask for the sudo password once up front, then keep the timestamp fresh
# in the background — long downloads/builds outlast the 5-min sudo cache
sudo -v
( while true; do sleep 60; sudo -n true; done ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT

# Update official packages
echo "📦 Updating official packages (pacman)..."
sudo pacman -Syu

# Update AUR packages (yay uses sudo, so the upfront auth covers it;
# pamac is not used here — it authenticates via polkit and would prompt again)
echo "🧩 Updating AUR packages (yay)..."
yay -Sua

echo "✅ System update completed!"
