# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal dotfiles for Linux (Manjaro/Arch, primary) and macOS (stub). The repo is **symlinked**, not copied: `install.sh` creates symlinks from `~` and `~/bin` back into the repo, so editing a file here immediately affects the live environment once links exist.

## Install / apply changes

```bash
cd ~/dotfiles && ./install.sh
```

`install.sh` is idempotent (`ln -sf`). It links the git/ssh configs from `utilities/git-hat/config-files/` and `common/zshrc` into `~`, links every `*.sh` in `git-scripts/`, `linux/` (including one-level subdirectories like `linux/update-system/`), and `macos/` into `~/bin` (stripping the `.sh` extension), links the `git-hat` utility into `~/bin` as both `git-hat` and `hat`, then runs the OS-specific setup (`linux/linux-setup.sh` on Linux). The Linux setup installs the base pacman packages (including `keyd`), installs `yay` (from Manjaro's repos, falling back to an AUR `makepkg` build on vanilla Arch — needed by `update-system`), symlinks `common/keyd/*.conf` into `/etc/keyd/` (sudo), enables the `keyd` service, and runs `keyd reload` — so editing `common/keyd/*.conf` in the repo edits the live `/etc/keyd` config (apply changes with `sudo keyd reload`). There is no build/lint/test step — this repo is shell + config only.

## Critical constraints

- **Clone path is hardcoded.** `install.sh` references `~/dotfiles/...` and the git/ssh configs use absolute `/home/dmitriy/...` paths. The repo must live at `~/dotfiles` for a user named `dmitriy`. Changing the username or location means editing `utilities/git-hat/config-files/gitconfig` (the `includeIf gitdir:` paths) and the `DIR` lines in `utilities/git-hat/personas/*.conf` by hand.
- **`~/bin` must be on `$PATH`.** `common/zshrc` adds it; all helper scripts are invoked by their basename (`hat`, `git-hat`, `update-system`).
- **A script is only usable after `install.sh` re-runs** — adding a new `*.sh` to `git-scripts/`/`linux/`/`macos/` does nothing until it's symlinked into `~/bin`.

## Git identity architecture

`utilities/git-hat/personas/*.conf` is the single source of truth for identities. `hat sync` generates the ssh host aliases and per-directory git identity from them into `utilities/git-hat/generated/`, which the checked-in static bases (symlinked into `~`) pull in:

- `config-files/gitconfig` → `~/.gitconfig`: static settings (`alias`/`init`/`credential`) + a default personal identity + an `include` of `generated/gitconfig-includes`.
- `config-files/ssh_config` → `~/.ssh/config`: an `Include` of `generated/ssh_config`.

Identity is then selected automatically by directory via the generated `includeIf` blocks (everything defaults to personal; persona dirs override):

- `~/Projects/Own/**` → personal
- `~/Projects/JuliusAgency/**` → office
- `~/Projects/Own-old/**` → work
- anywhere else → personal (default)

Each persona maps to an SSH host alias `github-<name>` (`github-personal`, `github-office`, `github-work`), bound to that persona's `KEY`.

### `git-hat` / `hat`

`utilities/git-hat/git-hat` is a small dispatcher, symlinked into `~/bin` as both `git-hat` and `hat`, and also usable as the git subcommand `git hat`. Personas are declared once in `utilities/git-hat/personas/<name>.conf` — sourced `KEY="value"` files with `NAME`, `EMAIL`, `KEY`, `DIR`. Commands:

- `hat whoami [path]` — print the persona for the current dir (or given path), by longest-prefix match on each persona's `DIR` (boundary-aware, so `Own-backup` ≠ `Own`).
- `hat clone <git-url>` — clone into `$PWD`, picking the persona from `$PWD` and rewriting the URL host to `github-<persona>`. Accepts both `git@github.com:org/repo.git` and `https://github.com/org/repo.git`; no persona for the cwd → error.
- `hat adopt` — fix a repo acquired without `hat clone` (plain `git clone` / `git remote add`): rewrite all GitHub remotes (`github.com`, https form, or a wrong `github-<persona>` alias) of the current repo to the persona of its directory. Non-GitHub remotes untouched; idempotent.
- `hat sync` — regenerate `ssh_config`, `gitconfig-<persona>` and `includeIf` blocks into `utilities/git-hat/generated/` from `personas/*.conf` (purging configs of removed personas), create each persona's `DIR`, and warn about missing SSH keys.
- `hat keygen` — generate an ed25519 key for every persona whose `KEY` file is missing (keys are gitignored, so a fresh machine has none), then offer to upload the pubkey via `gh ssh-key add` (mind `gh auth switch` — one gh account at a time, personas map to different accounts).
- `hat doctor` — new-machine health check: `gh` installed/authenticated, generated configs present, and per persona — `DIR` exists, `KEY` exists, live `ssh -T` auth test printing the GitHub account the key resolves to. Non-zero exit if anything fails.

So the directory a repo lands in is what makes `includeIf` pick the matching identity — use `hat clone` rather than `git clone` directly to keep identity and location consistent (or run `hat adopt` inside a repo to fix its remotes after the fact). Run `git config user.email` in any repo to confirm the identity it resolves to.

`generated/` is gitignored and is the wired-in live source — it is (re)generated by `hat sync`, which `install.sh` runs on every install. Add or change an identity by editing `personas/*.conf` and running `hat sync`; never hand-edit `generated/` or put identities back into `config-files/`.

GitHub HTTPS credentials are delegated to `gh auth git-credential` (configured in `config-files/gitconfig`), so `gh` must be installed and authenticated.

## When editing

- New shell scripts intended as global commands go in `git-scripts/` (git-related) or `linux/` (system) and require re-running `install.sh` to become available.
- To add a git persona: create `utilities/git-hat/personas/<name>.conf` (`NAME`/`EMAIL`/`KEY`/`DIR`) and run `hat sync` — that regenerates the `github-<name>` ssh alias and the `includeIf` identity mapping. The persona's `DIR` doubles as both the `includeIf` match and the `hat clone` destination root.
- keyd configs live in `common/keyd/*.conf` (symlinked into `/etc/keyd/` by the Linux setup). A new `*.conf` there needs a re-run of `install.sh` (or a manual `sudo ln -sf`) to be linked; content edits to already-linked files are live immediately but need `sudo keyd reload` to take effect.
- `*.pub` files are gitignored alongside private keys — SSH keys themselves are never committed; `ssh_config` only references key paths.
- macOS support is a stub (`macos/macos-setup.sh` exits 0); the Darwin branch in `install.sh` is unimplemented.
