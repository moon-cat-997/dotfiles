#!/bin/bash

set -e

echo "- Installing dotfiles..."

!TODO ask about username

# Detect OS
OS="$(uname -s)"
echo "- Detected OS: $OS"

# Ensure ~/bin exists
mkdir -p ~/bin

# ~/.ssh may not exist on a fresh machine — create it before linking ssh_config,
# otherwise `ln -sf ... ~/.ssh/config` fails and set -e aborts the install.
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Link config files
#   git/ssh configs live under utilities/git-hat/config-files/
#   zshrc lives under common/
#   gitconfig/ssh_config are static bases that `include` the generated files;
#   per-persona identities are produced by `git-hat sync` (see below).
GP_CONFIG=~/dotfiles/utilities/git-hat/config-files
ln -sf "$GP_CONFIG/gitconfig"  ~/.gitconfig
ln -sf "$GP_CONFIG/ssh_config" ~/.ssh/config
ln -sf ~/dotfiles/common/zshrc ~/.zshrc

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


# Link git-hat utility (usable as `git-hat`, `git hat`, or `hat`)
echo "- Linking git-hat..."
chmod +x ~/dotfiles/utilities/git-hat/git-hat
ln -sf ~/dotfiles/utilities/git-hat/git-hat "$HOME/bin/git-hat"
ln -sf ~/dotfiles/utilities/git-hat/git-hat "$HOME/bin/hat"
echo "  ✔ Linked git-hat, hat"

# Generate ssh/git identity configs from personas/ (source of truth) into generated/
echo "- Generating git-hat configs..."
~/dotfiles/utilities/git-hat/git-hat sync

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
