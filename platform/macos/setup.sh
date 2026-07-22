#!/bin/bash
#
# macOS platform setup. Called by install.sh on uname -s = Darwin.
#
# Mirror of platform/linux/setup.sh: owns everything Homebrew-specific plus the
# login shell and this platform's own ~/bin scripts. The agent CLIs come from
# common/install-agents.sh and the Claude/Codex configs from their sync buttons,
# so nothing here duplicates the Linux side.
#
# Not covered on purpose: keyd has no macOS counterpart (see Brewfile).

set -e

PLATFORM_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🍎 Running macOS setup..."

# Xcode Command Line Tools — git and the compilers Homebrew needs.
# `xcode-select --install` opens a GUI dialog and returns immediately, so this
# cannot be waited on non-interactively; ask the user to finish it and re-run.
if ! xcode-select -p >/dev/null 2>&1; then
  echo "📥 Installing Xcode Command Line Tools..."
  xcode-select --install || true
  echo "❌ Finish the Command Line Tools dialog, then re-run ./install.sh."
  exit 1
fi

# Homebrew. Apple Silicon installs to /opt/homebrew, Intel to /usr/local; the
# installer does not touch the current shell's PATH, so eval its shellenv here.
if ! command -v brew >/dev/null 2>&1; then
  echo "🍺 Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [ -x "$brew_bin" ]; then
    eval "$("$brew_bin" shellenv)"
    break
  fi
done

if ! command -v brew >/dev/null 2>&1; then
  echo "❌ Homebrew is still not on PATH — cannot install packages." >&2
  exit 1
fi

echo "📦 Installing packages from Brewfile..."
brew bundle --file "$PLATFORM_DIR/Brewfile"

# Default shell. macOS has shipped zsh as the default since Catalina, so this is
# usually already true; it matters on accounts migrated from older releases.
if [[ "$SHELL" != *zsh ]]; then
  echo "Setting Zsh as default shell..."
  chsh -s /bin/zsh
fi

# macOS-only helper scripts → ~/bin. The directory is optional (git does not
# track empty dirs), so the glob is guarded and this is a no-op until it exists.
echo "- Linking macOS scripts..."
for script in "$PLATFORM_DIR"/bin/*.sh "$PLATFORM_DIR"/bin/*/*.sh; do
  [ -e "$script" ] || continue
  chmod +x "$script"
  name=$(basename "$script" .sh)
  ln -sf "$script" "$HOME/bin/$name"
  echo "  ✔ Linked $name"
done

echo "macOS setup complete!"
