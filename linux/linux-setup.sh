#!/bin/bash

echo "🔧 Running Manjaro/Arch-based Linux setup..."

# Install basic packages (you can add more)
sudo pacman -Sy --needed git zsh stow curl wget neovim starship

# Optional: Set zsh as default shell
if [[ "$SHELL" != *zsh ]]; then
    echo "Setting Zsh as default shell..."
    chsh -s /bin/zsh
fi

echo "Linux Manjaro setup complete!"
