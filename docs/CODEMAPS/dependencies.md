<!-- Generated: 2026-07-22 | Files scanned: platform/**, common/install-agents.sh, config-files/ | Token estimate: ~560 -->

# Dependencies

External tools this repo installs or relies on. No language package manager —
OS packages + CLIs only. The two package lists are maintained separately by
design; see architecture.md for why they are not a mapped pair.

## Installed on Linux — platform/linux/packages.txt (via pacman --needed)

```
git github-cli zsh stow curl wget neovim starship xclip nodejs npm keyd
```

Plus, by `platform/linux/setup.sh` outside the list:

```
yay:  AUR helper — pacman, else AUR bootstrap (yay-bin via makepkg)
      kept out of packages.txt: an unknown target fails the whole transaction
```

## Installed on macOS — platform/macos/Brewfile (via brew bundle)

```
git gh stow wget neovim starship node
```

Plus, by `platform/macos/setup.sh` outside the Brewfile:

```
Xcode CLT:  guard only — triggers the GUI installer and asks for a re-run
Homebrew:   bootstrapped if absent; brew shellenv eval'd (prefix differs
            /opt/homebrew on Apple Silicon vs /usr/local on Intel)
```

Absent from the Brewfile on purpose: `zsh` and `curl` (built into macOS),
`xclip` (no counterpart — pbcopy/pbpaste), `keyd` (Linux-only; the nearest
macOS tool is Karabiner-Elements, left commented out since it needs an Input
Monitoring grant and its own config that `platform/linux/keyd/*.conf` do not
translate to).

## Installed on both — common/install-agents.sh

```
claude:  Claude Code CLI — curl claude.ai/install.sh → ~/.local/bin (skipped if present)
codex:   NOT auto-installed — channel differs per platform and changes often;
         presence is checked and a hint printed. codex-sync writes config anyway.
```

## Runtime relationships

```
gitconfig  ──credential.helper──>  gh auth git-credential   (resolved via PATH, not /usr/bin)
update-system  ──requires──>       yay (guard: exit 1 if missing)
keyd (systemd service)  ──reads──> /etc/keyd/*.conf → symlinks to platform/linux/keyd/*.conf
common/zshrc  ──expects──>         starship (prompt), ~/.local/bin + ~/bin on PATH
Claude hooks + statusline  ──run──> node   (why nodejs/node is in BOTH package lists)
codex-sync config merge  ──needs──> python3 >= 3.11 (tomllib); degrades with a warning
Claude configs  ──ref──>           MCP servers + plugins (from ~/.claude.json, settings.json — not synced)
```

## Package manager notes

- `pamac` deliberately avoided in update-system (polkit → re-prompts); `yay` is sudo-based, covered by one upfront `sudo -v`.
- On vanilla Arch `yay` is AUR-only → `base-devel` + `makepkg` fallback.

## Platform

- Linux Manjaro/Arch — primary, fully implemented and in daily use.
- macOS — implemented, but **not yet run on real hardware**; verified only by a
  sandboxed dual-branch `install.sh` run with stubbed `brew`/`pacman`/`sudo`.
