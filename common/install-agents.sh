#!/bin/bash
#
# install-agents — install the coding-agent CLIs. Identical on Linux and macOS,
# which is why this lives in common/ rather than in either platform's setup.sh
# (it used to sit inside the Linux branch, where a Mac would never have run it).
#
# Called by install.sh after the platform setup, so curl/brew/CLT already exist,
# and before claude-sync/codex-sync, which want the CLIs present.
# Installs only — never logs in. Auth is a one-time per-machine step.

set -e

echo "- Installing agent CLIs..."

# Claude Code: not in pacman or as a first-party formula; the official native
# installer covers both OSes and self-updates afterwards. Installs to
# ~/.local/bin, which common/zshrc puts on PATH.
if command -v claude >/dev/null 2>&1; then
  echo "  ✔ claude already installed ($(command -v claude))"
else
  echo "  🤖 Installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash
fi

# Codex: intentionally not auto-installed. Its distribution channel differs by
# platform and changes more often than this repo is updated, so guessing one
# here would mean a wrong `npm -g` or a wrong formula on a fresh machine.
# codex-sync writes the config either way — the CLI can arrive later.
if command -v codex >/dev/null 2>&1; then
  echo "  ✔ codex already installed ($(command -v codex))"
else
  echo "  ℹ codex not installed — common/codex/ configs will still be synced."
  echo "    Install it yourself, then re-run codex-sync."
fi

echo "✅ Agent CLIs ready."
