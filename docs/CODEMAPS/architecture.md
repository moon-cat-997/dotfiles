<!-- Generated: 2026-07-22 | Files scanned: ~35 source/config | Token estimate: ~760 -->

# Architecture

Personal dotfiles for Linux (Manjaro/Arch, primary) and macOS.
**Symlinked, not copied**: `install.sh` links `~` and `~/bin` back into the repo,
so editing a file here changes the live environment once links exist.

## Top-level split

```
common/     identical on every OS  (zshrc, claude/, codex/, install-agents.sh)
platform/   everything OS-specific (linux/, macos/ — each owns packages + bin/)
utilities/  git-hat (OS-agnostic after the portability fixes)
install.sh  thin orchestrator: shared → platform → sync
```

The rule: if it runs the same on both OSes it goes in `common/`; if it doesn't,
it goes in `platform/<os>/`. `keyd` lives under `platform/linux/` for exactly
this reason.

## Model

```
repo (~/dotfiles)                          live system
─────────────────                          ───────────
common/zshrc                       ──ln──> ~/.zshrc
utilities/git-hat/config-files/    ──ln──> ~/.gitconfig, ~/.ssh/config
common/claude/{settings,...}       ──ln──> ~/.claude/*          (via claude-sync)
common/codex/{AGENTS.md,skills}    ──ln──> ~/.codex/*           (via codex-sync)
platform/linux/keyd/*.conf         ──ln──> /etc/keyd/*.conf     (sudo, Linux)
git-scripts/*.sh                   ──ln──> ~/bin/<basename>     (both OSes)
platform/<os>/bin/**/*.sh          ──ln──> ~/bin/<basename>     (that OS only)
utilities/git-hat/git-hat          ──ln──> ~/bin/{git-hat,hat}
common/{claude,codex}/*-sync.sh    ──ln──> ~/bin/{claude-sync,codex-sync}
```

No build/lint/test — shell + config only. Apply changes: `cd ~/dotfiles && ./install.sh` (idempotent, `ln -sf`).

## Package lists are intentionally NOT shared

`platform/linux/packages.txt` (pacman) and `platform/macos/Brewfile` (brew bundle)
are maintained separately on purpose. Of the Linux entries: several are built into
macOS, `xclip` has no counterpart (pbcopy/pbpaste are built in), and `keyd` is a
different product entirely (Karabiner — left commented out). A cross-OS
name-mapping layer would be more code than the two lists it replaced.

## Hard constraints

- Clone path hardcoded to `~/dotfiles`. The **username is not** — all paths are
  `~`-relative and persona `DIR`/`KEY` are stored as literal `$HOME/...`, so the
  repo works under `/home/<user>` and `/Users/<user>`.
- Keep it that way: git ignores a missing `include.path` and ssh ignores a missing
  `Include` **silently**, so a wrong absolute path yields no identities and no error.
- `~/bin` must be on `$PATH` (added by `common/zshrc`); helper scripts run by basename.
- A new `*.sh` is inert until `install.sh` re-runs and symlinks it into `~/bin`.
- `~/.claude/*` are symlinks **into this repo**. Anything that "manages"
  `~/.claude/rules`, `hooks`, `skills`, … is editing tracked files here; a tool that
  rebuilds one of those directories deletes the repo's copy. Check `git status`
  after running any Claude Code installer/configurator.

## User-facing commands (~/bin)

| Command | Source | Role | OS |
|---|---|---|---|
| `hat` / `git-hat` | `utilities/git-hat/git-hat` | git identity per directory (see git-hat.md) | both |
| `claude-sync` | `common/claude/claude-sync.sh` | link Claude configs + restore user-scope MCP servers (see claude-config.md) | both |
| `codex-sync` | `common/codex/codex-sync.sh` | link Codex baseline + merge config.toml (see codex-sync.md) | both |
| `update-system` | `platform/linux/bin/update-system.sh` | pacman + AUR full update | Linux |

## Subsystems (see per-area codemaps)

- **install-flow.md** — `install.sh` three phases + platform dispatch
- **git-hat.md** — multi-persona git/ssh identity
- **claude-config.md** — portable Claude Code setup
- **codex-sync.md** — portable Codex setup
- **dependencies.md** — external tools relied on
