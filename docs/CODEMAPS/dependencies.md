<!-- Generated: 2026-07-16 | Files scanned: linux-setup.sh, update-system.sh, config-files/ | Token estimate: ~450 -->

# Dependencies

External tools this repo installs or relies on. No language package manager — OS packages + CLIs only.

## Installed by linux-setup.sh

```
pacman (--needed): git github-cli zsh stow curl wget neovim starship xclip keyd
yay:               AUR helper — pacman, else AUR bootstrap (yay-bin via makepkg)
claude:            Claude Code CLI — curl claude.ai/install.sh → ~/.local/bin (skipped if present)
```

## Runtime relationships

```
gitconfig  ──credential.helper──>  gh auth git-credential   (github-cli must be authed)
update-system  ──requires──>       yay (guard: exit 1 if missing)
keyd (systemd service)  ──reads──> /etc/keyd/*.conf → symlinks to common/keyd/*.conf
common/zshrc  ──expects──>         starship (prompt), ~/.local/bin + ~/bin on PATH
Claude configs  ──ref──>           MCP servers + plugins (from ~/.claude.json, settings.json — not synced)
```

## Package manager notes

- `pamac` deliberately avoided in update-system (polkit → re-prompts); `yay` is sudo-based, covered by one upfront `sudo -v`.
- On vanilla Arch `yay` is AUR-only → `base-devel` + `makepkg` fallback.

## Platform

- Linux Manjaro/Arch — primary, fully implemented.
- macOS — stub (`macos/macos-setup.sh` exits 0; Darwin branch unimplemented).
