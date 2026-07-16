<!-- Generated: 2026-07-16 | Files scanned: ~30 source/config | Token estimate: ~650 -->

# Architecture

Personal dotfiles for Linux (Manjaro/Arch primary) and macOS (stub).
**Symlinked, not copied**: `install.sh` links `~` and `~/bin` back into the repo,
so editing a file here changes the live environment once links exist.

## Model

```
repo (~/dotfiles)                        live system
─────────────────                        ───────────
common/zshrc                     ──ln──> ~/.zshrc
utilities/git-hat/config-files/  ──ln──> ~/.gitconfig, ~/.ssh/config
common/claude/{settings,...}     ──ln──> ~/.claude/*
common/keyd/*.conf               ──ln──> /etc/keyd/*.conf   (sudo, Linux)
git-scripts/*.sh, linux/**/*.sh  ──ln──> ~/bin/<basename>   (.sh stripped)
utilities/git-hat/git-hat        ──ln──> ~/bin/{git-hat,hat}
```

No build/lint/test — shell + config only. Apply changes: `cd ~/dotfiles && ./install.sh` (idempotent, `ln -sf`).

## Hard constraints

- Clone path hardcoded to `~/dotfiles` for user `dmitriy`; absolute `/home/dmitriy/...`
  paths in gitconfig + personas. Moving/renaming needs manual edits.
- `~/bin` must be on `$PATH` (added by `common/zshrc`); helper scripts run by basename.
- A new `*.sh` is inert until `install.sh` re-runs and symlinks it into `~/bin`.

## User-facing commands (~/bin)

| Command | Source | Role |
|---|---|---|
| `hat` / `git-hat` | `utilities/git-hat/git-hat` | git identity per directory (see git-hat.md) |
| `update-system` | `linux/update-system/update-system.sh` | pacman + AUR full update |

## Subsystems (see per-area codemaps)

- **install-flow.md** — `install.sh` orchestration + OS branch
- **git-hat.md** — multi-persona git/ssh identity
- **claude-config.md** — portable Claude Code setup
- **dependencies.md** — external tools relied on
