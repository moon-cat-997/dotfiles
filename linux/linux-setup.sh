#!/bin/bash

echo "🔧 Running Manjaro/Arch-based Linux setup..."

# Install basic packages (you can add more)
# github-cli: gitconfig delegates HTTPS credentials to /usr/bin/gh
sudo pacman -Sy --needed git github-cli zsh stow curl wget neovim starship xclip

# Optional: Set zsh as default shell
if [[ "$SHELL" != *zsh ]]; then
    echo "Setting Zsh as default shell..."
    chsh -s /bin/zsh
fi

echo "Linux Manjaro setup complete!"
