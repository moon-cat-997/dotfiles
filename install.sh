#!/bin/bash

set -e

echo "- Installing dotfiles..."

!TODO ask about username

# Detect OS
OS="$(uname -s)"
echo "- Detected OS: $OS"

# Ensure ~/bin exists
mkdir -p ~/bin

# Link common config files
ln -sf ~/dotfiles/common/gitconfig ~/.gitconfig
ln -sf ~/dotfiles/common/gitconfig-personal ~/.gitconfig-personal
ln -sf ~/dotfiles/common/gitconfig-work ~/.gitconfig-work
ln -sf ~/dotfiles/common/zshrc ~/.zshrc
ln -sf ~/dotfiles/common/ssh_config ~/.ssh/config

# !TODO Create directories Projects/Own; Projects/JuliusAgency;
# !TODO Create .ssh-keys if needed

# Make git-scripts executable and link them
echo "- Linking git scripts..."
for script in ~/dotfiles/git-scripts/*.sh; do
  chmod +x "$script"
  name=$(basename "$script" .sh)
  ln -sf "$script" "$HOME/bin/$name"
  echo "  ✔ Linked $name"
done

# Make linux-scripts executable and link them
echo "- Linking git scripts..."
for script in ~/dotfiles/linux/*.sh; do
  chmod +x "$script"
  name=$(basename "$script" .sh)
  ln -sf "$script" "$HOME/bin/$name"
  echo "  ✔ Linked $name"
done

# Make macos executable and link them
echo "- Linking git scripts..."
for script in ~/dotfiles/macos/*.sh; do
  chmod +x "$script"
  name=$(basename "$script" .sh)
  ln -sf "$script" "$HOME/bin/$name"
  echo "  ✔ Linked $name"
done 


# Run OS-specific setup
case "$OS" in
  Linux)
    echo "🐧 Running Linux setup..."
    bash ~/dotfiles/linux/linux-setup.sh
    ;;
  Darwin)
    echo "🍎 macOS support is not yet implemented."
    ;;
  *)
    echo "❌ Unsupported OS: $OS"
    exit 1
    ;;
esac

echo "✅ Done!"
