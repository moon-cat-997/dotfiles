#!/bin/bash
#
# Linux (Manjaro/Arch) platform setup. Called by install.sh on uname -s = Linux.
#
# Owns everything pacman/systemd-specific: base packages, the yay AUR helper,
# keyd, the login shell, and linking this platform's own scripts into ~/bin.
# Cross-platform concerns live elsewhere — the agent CLIs are installed by
# common/install-agents.sh, and the Claude/Codex configs by their sync buttons.

set -e

PLATFORM_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔧 Running Manjaro/Arch-based Linux setup..."

# Base packages, declared in packages.txt (strip '#' comments and blank lines).
# Unquoted on purpose: the list must word-split into separate pacman targets.
packages=$(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$PLATFORM_DIR/packages.txt" | tr '\n' ' ')
echo "📦 Installing base packages: $packages"
# shellcheck disable=SC2086
sudo pacman -Sy --needed $packages

# yay: AUR helper used by update-system (sudo-based, unlike polkit-based pamac).
# In Manjaro's extra repo; on vanilla Arch it's AUR-only, so fall back to makepkg.
# Kept out of packages.txt — an unknown target there would fail the whole install.
if ! command -v yay >/dev/null 2>&1; then
  echo "📥 Installing yay..."
  if ! sudo pacman -S --needed --noconfirm yay; then
    echo "  yay not in repos — bootstrapping from AUR..."
    sudo pacman -S --needed --noconfirm base-devel git
    yay_tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$yay_tmp"
    (cd "$yay_tmp" && makepkg -si --noconfirm)
    rm -rf "$yay_tmp"
  fi
fi

# Optional: Set zsh as default shell
if [[ "$SHELL" != *zsh ]]; then
    echo "Setting Zsh as default shell..."
    chsh -s /bin/zsh
fi

# Linux-only helper scripts → ~/bin (top level and one-level subdirectories).
# Owned by this platform rather than install.sh so a Mac never ends up with
# pacman-based tools like update-system on its PATH.
echo "- Linking Linux scripts..."
for script in "$PLATFORM_DIR"/bin/*.sh "$PLATFORM_DIR"/bin/*/*.sh; do
  [ -e "$script" ] || continue
  chmod +x "$script"
  name=$(basename "$script" .sh)
  ln -sf "$script" "$HOME/bin/$name"
  echo "  ✔ Linked $name"
done

# keyd: symlink configs from the repo into /etc/keyd so edits in
# platform/linux/keyd/*.conf are live in /etc (apply with `sudo keyd reload`)
echo "⌨️  Setting up keyd..."
sudo mkdir -p /etc/keyd
for conf in "$PLATFORM_DIR"/keyd/*.conf; do
  [ -e "$conf" ] || continue
  sudo ln -sf "$conf" "/etc/keyd/$(basename "$conf")"
  echo "  ✔ Linked $(basename "$conf")"
done
sudo systemctl enable --now keyd
sudo keyd reload

echo "Linux Manjaro setup complete!"
