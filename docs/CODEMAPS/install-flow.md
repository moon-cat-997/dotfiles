<!-- Generated: 2026-07-16 | Files scanned: install.sh, linux-setup.sh, update-system.sh | Token estimate: ~600 -->

# Install Flow

Entry point: `install.sh` (108 lines). Idempotent; `set -e`.

## install.sh — step order

```
1. mkdir ~/bin, ~/.ssh (chmod 700)
2. Link static configs:
     utilities/git-hat/config-files/gitconfig  → ~/.gitconfig
     utilities/git-hat/config-files/ssh_config → ~/.ssh/config
     common/zshrc                               → ~/.zshrc
3. Link Claude configs (loop) → ~/.claude/<item>
     items: settings.json CLAUDE.md statusline-command.sh hooks scripts skills commands rules
     ln -sfn; pre-existing REAL file/dir backed up once as *.pre-dotfiles
4. Link scripts → ~/bin/<basename .sh>:
     git-scripts/*.sh   (dir may be absent)
     linux/*.sh linux/*/*.sh   (top-level + 1 subdir deep)
     macos/*.sh
5. Link git-hat → ~/bin/{git-hat,hat}
6. Run `git-hat sync`  (regenerate generated/ from personas/)
7. OS branch:
     Linux  → bash linux/linux-setup.sh
     Darwin → no-op message (unimplemented)
     other  → exit 1
```

## linux/linux-setup.sh (50 lines)

```
- pacman -Sy --needed: git github-cli zsh stow curl wget neovim starship xclip keyd
- yay: pacman install, else bootstrap from AUR (yay-bin via makepkg)   # needed by update-system
- chsh -s /bin/zsh if not already zsh
- Claude Code CLI: curl claude.ai/install.sh | bash  (skipped if `claude` present → ~/.local/bin)
- keyd: symlink common/keyd/*.conf → /etc/keyd/, systemctl enable --now keyd, keyd reload
```

## linux/update-system/update-system.sh (29 lines) → `update-system`

```
- guard: yay present else exit 1
- sudo -v once + background keepalive (sleep 60 loop), trap-killed on EXIT
- pacman -Syu
- yay -Sua   (AUR; sudo-based, covered by upfront auth — pamac avoided, it re-prompts via polkit)
```

## macos/macos-setup.sh — stub (`exit 0`); Darwin branch in install.sh unimplemented.

## Gotchas

- Editing `common/keyd/*.conf` is live in `/etc` (symlinked) but needs `sudo keyd reload`.
- If Claude Code rewrites `settings.json` into a plain file (breaking the symlink), re-run `install.sh`.
