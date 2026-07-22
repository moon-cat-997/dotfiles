# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal dotfiles for Linux (Manjaro/Arch, primary) and macOS (stub). The repo is **symlinked**, not copied: `install.sh` creates symlinks from `~` and `~/bin` back into the repo, so editing a file here immediately affects the live environment once links exist.

## Install / apply changes

```bash
cd ~/dotfiles && ./install.sh
```

`install.sh` is idempotent (`ln -sf`). It links the git/ssh configs from `utilities/git-hat/config-files/` and `common/zshrc` into `~`, links every `*.sh` in `git-scripts/`, `linux/` (including one-level subdirectories like `linux/update-system/`), and `macos/` into `~/bin` (stripping the `.sh` extension), links the `git-hat` utility into `~/bin` as both `git-hat` and `hat` and `common/claude/claude-sync.sh` into `~/bin` as `claude-sync`, runs the OS-specific setup (`linux/linux-setup.sh` on Linux), then runs `claude-sync` to apply the Claude Code configs (see below — it runs last so a fresh machine already has the `claude` CLI installed by the OS setup). The Linux setup installs the base pacman packages (including `keyd`), installs `yay` (from Manjaro's repos, falling back to an AUR `makepkg` build on vanilla Arch — needed by `update-system`), installs Claude Code via the official native installer (`claude.ai/install.sh` → `~/.local/bin`, skipped if present), symlinks `common/keyd/*.conf` into `/etc/keyd/` (sudo), enables the `keyd` service, and runs `keyd reload` — so editing `common/keyd/*.conf` in the repo edits the live `/etc/keyd` config (apply changes with `sudo keyd reload`). There is no build/lint/test step — this repo is shell + config only.

## Critical constraints

- **Clone path is hardcoded, but the username is not.** `install.sh` and the git/ssh config bases reference `~/dotfiles/...`, and persona `DIR`/`KEY` values are stored as literal `$HOME/...`, so the repo works for any username on both `/home/<user>` (Linux) and `/Users/<user>` (macOS). It must still live at `~/dotfiles`. Keep it that way: git silently ignores a missing `include.path` and ssh silently ignores a missing `Include`, so an absolute path that's wrong on another machine fails with no error at all — you just get no identities.
- **`~/bin` must be on `$PATH`.** `common/zshrc` adds it; all helper scripts are invoked by their basename (`hat`, `git-hat`, `update-system`).
- **A script is only usable after `install.sh` re-runs** — adding a new `*.sh` to `git-scripts/`/`linux/`/`macos/` does nothing until it's symlinked into `~/bin`.

## Claude Code configs

`common/claude/` is the source of truth for the portable Claude Code setup: `settings.json` (statusline, hooks, permissions, enabled plugins/marketplaces), the global `CLAUDE.md`, `statusline-command.sh`, `hooks/`, `scripts/` (hook runners referenced by settings), `skills/`, `commands/`, `rules/`, and `mcp-servers.conf` (user-scope MCP servers, `name url` per line).

`common/claude/claude-sync.sh` (in `~/bin` as `claude-sync`, also called at the end of `install.sh`) is the one button that applies it all, idempotently: it symlinks each config into `~/.claude/` (`ln -sfn`; a pre-existing real file/dir is backed up as `*.pre-dotfiles`), then registers every server from `mcp-servers.conf` that's missing via `claude mcp add --scope user --transport http` (skipped with a notice if the `claude` CLI isn't on PATH). It never performs any login: Claude auth is a one-time `claude` login per machine, and each MCP server OAuths lazily on first use. Edits in the repo are live immediately — on any machine, including macOS; to add an MCP server, add a line to `mcp-servers.conf` and run `claude-sync`.

Not synced on purpose: `~/.claude.json` (machine state; MCP server entries are restored from `mcp-servers.conf` instead), `~/.claude/.credentials.json` / macOS Keychain (OAuth tokens), `~/.claude/settings.local.json` (machine-local overrides), and `~/.claude/plugins/` (Claude Code reinstalls plugins itself from `enabledPlugins` + `extraKnownMarketplaces` in settings.json). Paths inside settings.json use `$HOME`, except the `pika-dev` marketplace `directory` path, which is inherently machine-specific (that plugin stays inactive on a machine until `~/Projects/Own/pika-orch` exists). If Claude Code ever rewrites `settings.json` in a way that replaces the symlink with a plain file, `claude-sync` detects the drift, saves the file as `settings.json.drift-<timestamp>` for diffing into the repo, and restores the symlink.

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

- `hat whoami [path]` — print the persona for the current dir (or given path) plus its identity (`personal — Name <email> (git@github-personal)`), by longest-prefix match on each persona's `DIR` (boundary-aware, so `Own-backup` ≠ `Own`). The live GitHub login of the key is `hat doctor`'s job (network).
- `hat clone <git-url>` — clone into `$PWD`, picking the persona from `$PWD` and rewriting the URL host to `github-<persona>`. Accepts both `git@github.com:org/repo.git` and `https://github.com/org/repo.git`; no persona for the cwd → error.
- `hat remote-add <git-url> [name]` — add a remote (default `origin`) to the current repo under the persona alias of its directory. This is the one-step form of GitHub's suggested `git remote add origin git@github.com:org/repo.git` for a pre-existing local repo pushed to a freshly-created GitHub repo — the host lands as `github-<persona>` immediately, so no follow-up `hat adopt` is needed. Same URL forms as `hat clone`; errors if the remote name already exists (use `hat adopt` to rewrite an existing one) or if there's no persona for the repo's directory.
- `hat adopt` — fix a repo acquired without `hat clone` (plain `git clone` / `git remote add`): rewrite all GitHub remotes (`github.com`, https form, or a wrong `github-<persona>` alias) of the current repo to the persona of its directory. Non-GitHub remotes untouched; idempotent.
- `hat add <name>` — create a persona interactively: prompts for NAME/EMAIL/KEY/DIR (defaults derived from the name, `~/…` stored as literal `$HOME/…`), writes `personas/<name>.conf`, runs `hat sync`, offers `hat keygen`. Warns when the new DIR overlaps another persona's DIR.
- `hat remove <name>` — delete a persona after a confirmation prompt, with a preflight report: repos under its DIR whose remotes point at the vanishing `github-<name>` alias (they'd break), and a fallback-to-default-identity warning. Deletes the conf and re-syncs; DIR is never touched, the key is deleted only on separate explicit consent (GitHub-side pubkey must be revoked manually).
- `hat sync` — regenerate `ssh_config`, `gitconfig-<persona>` and `includeIf` blocks into `utilities/git-hat/generated/` from `personas/*.conf` (purging configs of removed personas), create each persona's `DIR`, and warn about missing SSH keys.
- `hat keygen` — generate an ed25519 key for every persona whose `KEY` file is missing (keys are gitignored, so a fresh machine has none), then offer to upload the pubkey via `gh ssh-key add` (mind `gh auth switch` — one gh account at a time, personas map to different accounts).
- `hat doctor` — new-machine health check: `gh` installed/authenticated, generated configs present, and per persona — `DIR` exists, `KEY` exists, live `ssh -T` auth test printing the GitHub account the key resolves to. Non-zero exit if anything fails.

So the directory a repo lands in is what makes `includeIf` pick the matching identity — use `hat clone` rather than `git clone` directly to keep identity and location consistent (or run `hat adopt` inside a repo to fix its remotes after the fact). Run `git config user.email` in any repo to confirm the identity it resolves to.

`generated/` is gitignored and is the wired-in live source — it is (re)generated by `hat sync`, which `install.sh` runs on every install. Add or change an identity by editing `personas/*.conf` and running `hat sync`; never hand-edit `generated/` or put identities back into `config-files/`.

GitHub HTTPS credentials are delegated to `gh auth git-credential` (configured in `config-files/gitconfig`), so `gh` must be installed and authenticated.

## When editing

- New shell scripts intended as global commands go in `git-scripts/` (git-related) or `linux/` (system) and require re-running `install.sh` to become available.
- To add a git persona: run `hat add <name>` (or manually create `utilities/git-hat/personas/<name>.conf` with `NAME`/`EMAIL`/`KEY`/`DIR` and run `hat sync`) — that regenerates the `github-<name>` ssh alias and the `includeIf` identity mapping. The persona's `DIR` doubles as both the `includeIf` match and the `hat clone` destination root. To delete one: `hat remove <name>` (confirmation-gated; never touches the persona's DIR).
- keyd configs live in `common/keyd/*.conf` (symlinked into `/etc/keyd/` by the Linux setup). A new `*.conf` there needs a re-run of `install.sh` (or a manual `sudo ln -sf`) to be linked; content edits to already-linked files are live immediately but need `sudo keyd reload` to take effect.
- `*.pub` files are gitignored alongside private keys — SSH keys themselves are never committed; `ssh_config` only references key paths.
- macOS support is a stub (`macos/macos-setup.sh` exits 0); the Darwin branch in `install.sh` is unimplemented.
