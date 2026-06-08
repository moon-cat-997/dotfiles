# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal dotfiles for Linux (Manjaro/Arch, primary) and macOS (stub). The repo is **symlinked**, not copied: `install.sh` creates symlinks from `~` and `~/bin` back into the repo, so editing a file here immediately affects the live environment once links exist.

## Install / apply changes

```bash
cd ~/dotfiles && ./install.sh
```

`install.sh` is idempotent (`ln -sf`). It links the `common/` configs into `~`, links every `*.sh` in `git-scripts/`, `linux/`, and `macos/` into `~/bin` (stripping the `.sh` extension), then runs the OS-specific setup (`linux/linux-setup.sh` on Linux). There is no build/lint/test step — this repo is shell + config only.

## Critical constraints

- **Clone path is hardcoded.** `install.sh` references `~/dotfiles/...` and the git/ssh configs use absolute `/home/dmitriy/...` paths. The repo must live at `~/dotfiles` for a user named `dmitriy`. Changing the username or location means editing `common/gitconfig` (the `includeIf gitdir:` paths) by hand.
- **`~/bin` must be on `$PATH`.** `common/zshrc` adds it; all helper scripts are invoked by their basename (`git-whoami`, `clone-work`, `update-system`, `copyclip`).
- **A script is only usable after `install.sh` re-runs** — adding a new `*.sh` to `git-scripts/`/`linux/`/`macos/` does nothing until it's symlinked into `~/bin`.

## Git identity architecture

Identity is selected automatically by directory via `includeIf` in `common/gitconfig`:

- `~/Projects/JuliusAgency/**` → work identity (`common/gitconfig-work`)
- `~/Projects/Own/**` → personal identity (`common/gitconfig-personal`)
- everything else under `/home` → personal (fallback)

This pairs with SSH host aliases in `common/ssh_config` (`github-personal`, `github-work`, `github-office`), each bound to a different key. The clone helpers wire the two together:

- `clone-personal user/repo` → clones via `github-personal` into `~/Projects/Own/`
- `clone-work user/repo` → clones via `github-work` into `~/Projects/JuliusAgency/`

So the directory a repo lands in is what makes `includeIf` pick the matching identity — use the clone helpers rather than `git clone` directly to keep identity and location consistent. Run `git-whoami` in any repo to print which config/identity is active.

GitHub HTTPS credentials are delegated to `gh auth git-credential` (configured in `common/gitconfig`), so `gh` must be installed and authenticated.

## When editing

- New shell scripts intended as global commands go in `git-scripts/` (git-related) or `linux/` (system) and require re-running `install.sh` to become available.
- `*.pub` files are gitignored alongside private keys — SSH keys themselves are never committed; `ssh_config` only references key paths.
- macOS support is a stub (`macos/macos-setup.sh` exits 0); the Darwin branch in `install.sh` is unimplemented.
