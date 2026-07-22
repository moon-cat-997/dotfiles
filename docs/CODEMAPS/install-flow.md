<!-- Generated: 2026-07-22 | Files scanned: install.sh, platform/**, common/install-agents.sh, claude-sync.sh, codex-sync.sh | Token estimate: ~780 -->

# Install Flow

Entry point: `install.sh` (~100 lines). Idempotent; `set -e`.
Three phases: **shared → platform → sync**. Anything OS-specific lives in
`platform/`, never in `install.sh`.

## install.sh — step order

```
   mkdir ~/bin, ~/.ssh (chmod 700); OS="$(uname -s)"

1. SHARED
   Link static configs:
     utilities/git-hat/config-files/gitconfig  → ~/.gitconfig
     utilities/git-hat/config-files/ssh_config → ~/.ssh/config
     common/zshrc                              → ~/.zshrc
   Link cross-OS scripts → ~/bin/<basename .sh>:
     git-scripts/*.sh   (dir may be absent)
   Link buttons/utilities → ~/bin:
     claude-sync, codex-sync, git-hat, hat
   Run `git-hat sync`  (regenerate generated/ from personas/)

2. PLATFORM  (dispatch on uname -s)
     Linux  → bash platform/linux/setup.sh
     Darwin → bash platform/macos/setup.sh
     other  → exit 1

3. SYNC
   bash common/install-agents.sh          (agent CLIs — same on both OSes)
   bash common/claude/claude-sync.sh
   bash common/codex/codex-sync.sh
```

Ordering rationale: platform setup runs before phase 3 so `curl`/`brew` exist;
`install-agents.sh` runs before the sync buttons so `claude mcp add` can register
the user-scope MCP servers.

**Each platform links its own `bin/`** — `install.sh` deliberately does not glob
OS-specific script dirs. That is what keeps pacman-based `update-system` off a
Mac's PATH.

Claude config linking + MCP restore lives in `claude-sync.sh`; see
claude-config.md for internals (symlink loop, drift repair, MCP registration).
Codex config linking + baseline merge lives in `codex-sync.sh`; see codex-sync.md.

## platform/linux/setup.sh (~68 lines)

```
- packages: sed-strip comments from packages.txt → pacman -Sy --needed $packages
- yay: pacman install, else bootstrap from AUR (yay-bin via makepkg)  # needed by update-system
- chsh -s /bin/zsh if not already zsh
- link platform/linux/bin/*.sh and bin/*/*.sh → ~/bin
- keyd: symlink platform/linux/keyd/*.conf → /etc/keyd/, systemctl enable --now keyd, keyd reload
```

## platform/macos/setup.sh (~67 lines)

```
- Xcode CLT: xcode-select -p guard; triggers installer and exits 1 asking for a
    re-run (xcode-select --install is an async GUI dialog — cannot be waited on)
- Homebrew: install if absent, then eval "$(brew shellenv)" from /opt/homebrew
    or /usr/local (prefix differs Apple Silicon vs Intel; installer does not
    touch the running shell). Hard-fails if brew is still not on PATH.
- brew bundle --file platform/macos/Brewfile
- chsh -s /bin/zsh if not already zsh
- link platform/macos/bin/*.sh → ~/bin  (dir optional; glob is guarded)
```

## common/install-agents.sh (~36 lines)

```
- claude: curl claude.ai/install.sh | bash  → ~/.local/bin  (skipped if present)
- codex:  NOT auto-installed — distribution channel differs per platform and
          changes often. Prints a hint; codex-sync writes the config regardless.
```

Lives in `common/` because the installer is identical on both OSes. It used to
sit inside the Linux branch, where a Mac would never have reached it.

## platform/linux/bin/update-system.sh (29 lines) → `update-system`

```
- guard: yay present else exit 1
- sudo -v once + background keepalive (sleep 60 loop), trap-killed on EXIT
- pacman -Syu
- yay -Sua   (AUR; sudo-based, covered by upfront auth — pamac avoided, it re-prompts via polkit)
```

## Gotchas

- Editing `platform/linux/keyd/*.conf` is live in `/etc` (symlinked) but needs `sudo keyd reload`.
- If Claude Code rewrites `settings.json` into a plain file (breaking the symlink),
  re-run `claude-sync` — it saves the drift as `settings.json.drift-<timestamp>` and relinks.
- macOS is implemented but unverified on real hardware — only a sandboxed dual-branch
  run of `install.sh` with stubbed `brew`/`sudo`.
- Adding a package to one platform list does **not** imply the other; the lists are
  intentionally unmapped (see architecture.md).
