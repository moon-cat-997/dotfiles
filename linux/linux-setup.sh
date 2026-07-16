#!/bin/bash

echo "🔧 Running Manjaro/Arch-based Linux setup..."

# Install basic packages (you can add more)
# github-cli: gitconfig delegates HTTPS credentials to /usr/bin/gh
# keyd: system-wide key remapping daemon (configs in common/keyd/)
sudo pacman -Sy --needed git github-cli zsh stow curl wget neovim starship xclip keyd

# yay: AUR helper used by update-system (sudo-based, unlike polkit-based pamac).
# In Manjaro's extra repo; on vanilla Arch it's AUR-only, so fall back to makepkg.
# Kept out of the main pacman list — an unknown target there would fail the whole install.
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

# Claude Code CLI — not in pacman repos; official native installer
# (self-updating, installs to ~/.local/bin — on PATH via common/zshrc)
if ! command -v claude >/dev/null 2>&1; then
  echo "🤖 Installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash
fi

# keyd: symlink configs from the repo into /etc/keyd so edits in
# common/keyd/*.conf are live in /etc (apply with `sudo keyd reload`)
echo "⌨️  Setting up keyd..."
sudo mkdir -p /etc/keyd
for conf in ~/dotfiles/common/keyd/*.conf; do
  [ -e "$conf" ] || continue
  sudo ln -sf "$conf" "/etc/keyd/$(basename "$conf")"
  echo "  ✔ Linked $(basename "$conf")"
done
sudo systemctl enable --now keyd
sudo keyd reload

echo "Linux Manjaro setup complete!"
