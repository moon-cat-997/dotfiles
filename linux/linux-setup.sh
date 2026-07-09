#!/bin/bash

echo "🔧 Running Manjaro/Arch-based Linux setup..."

# Install basic packages (you can add more)
# github-cli: gitconfig delegates HTTPS credentials to /usr/bin/gh
# keyd: system-wide key remapping daemon (configs in common/keyd/)
sudo pacman -Sy --needed git github-cli zsh stow curl wget neovim starship xclip keyd

# Optional: Set zsh as default shell
if [[ "$SHELL" != *zsh ]]; then
    echo "Setting Zsh as default shell..."
    chsh -s /bin/zsh
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
