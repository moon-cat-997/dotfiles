# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal dotfiles for Linux (Manjaro/Arch, primary) and macOS (stub). The repo is **symlinked**, not copied: `install.sh` creates symlinks from `~` and `~/bin` back into the repo, so editing a file here immediately affects the live environment once links exist.

## Install / apply changes

```bash
cd ~/dotfiles && ./install.sh
```

`install.sh` is idempotent (`ln -sf`) and runs in three phases:

1. **Shared** — links the git/ssh configs from `utilities/git-hat/config-files/` and `common/zshrc` into `~`, links every `*.sh` in `git-scripts/` into `~/bin` (stripping the `.sh`), links `git-hat` into `~/bin` as both `git-hat` and `hat`, links the two sync buttons as `claude-sync`/`codex-sync`, then runs `hat sync` to generate the per-persona identity configs.
2. **Platform** — dispatches on `uname -s` to `platform/linux/setup.sh` or `platform/macos/setup.sh`. Each owns its own package list *and* links its own `bin/` into `~/bin`, which is why a Mac never ends up with pacman-based tools like `update-system` on its PATH.
3. **Sync** — `common/install-agents.sh` (the agent CLIs — same on both OSes), then `claude-sync`, then `codex-sync`. Runs last so the CLIs exist before their configs are applied.

The **Linux** setup installs the packages listed in `platform/linux/packages.txt` via pacman, installs `yay` (from Manjaro's repos, falling back to an AUR `makepkg` build on vanilla Arch — needed by `update-system`), sets zsh as the login shell, links `platform/linux/bin/*.sh` into `~/bin`, symlinks `platform/linux/keyd/*.conf` into `/etc/keyd/` (sudo), enables the `keyd` service and runs `keyd reload` — so editing `platform/linux/keyd/*.conf` in the repo edits the live `/etc/keyd` config (apply changes with `sudo keyd reload`).

The **macOS** setup requires the Xcode Command Line Tools (it triggers the installer and asks you to re-run if they're missing, since `xcode-select --install` is an async GUI dialog), installs Homebrew if absent, `eval`s `brew shellenv` (the installer doesn't touch the running shell, and the prefix differs between Apple Silicon and Intel), then applies `platform/macos/Brewfile` via `brew bundle`.

The two package lists are deliberately **not** a mapped pair — of the Linux entries, several are built into macOS, `xclip` has no counterpart, and `keyd` is a different product entirely, so a shared name-mapping layer would be more code than the two lists it replaced. See the header comments in both files.

There is no build/lint/test step — this repo is shell + config only.

## Critical constraints

- **Clone path is hardcoded, but the username is not.** `install.sh` and the git/ssh config bases reference `~/dotfiles/...`, and persona `DIR`/`KEY` values are stored as literal `$HOME/...`, so the repo works for any username on both `/home/<user>` (Linux) and `/Users/<user>` (macOS). It must still live at `~/dotfiles`. Keep it that way: git silently ignores a missing `include.path` and ssh silently ignores a missing `Include`, so an absolute path that's wrong on another machine fails with no error at all — you just get no identities.
- **`~/bin` must be on `$PATH`.** `common/zshrc` adds it; all helper scripts are invoked by their basename (`hat`, `git-hat`, `update-system`).
- **A script is only usable after `install.sh` re-runs** — adding a new `*.sh` to `git-scripts/` or `platform/<os>/bin/` does nothing until it's symlinked into `~/bin`.
- **`~/.claude/*` are symlinks into this repo.** `claude-sync` links `settings.json`, `CLAUDE.md`, `hooks`, `scripts`, `skills`, `commands` and `rules` from `common/claude/`. Anything that "manages" those paths under `~/.claude` is therefore editing tracked files in `~/dotfiles` — a tool that rebuilds `~/.claude/rules/` will delete this repo's `rules/` content. `claude-sync` detects the plain-file drift case (`settings.json`) but cannot catch a directory rebuilt in place. Check `git status` after running any Claude Code installer/configurator.

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

- New shell scripts intended as global commands go in `git-scripts/` if they work on every OS, or `platform/<os>/bin/` if they don't. Either way, re-run `install.sh` to make them available. Putting an OS-specific script in `git-scripts/` is the mistake to avoid — it will be linked into `~/bin` on both platforms.
- New packages go in `platform/linux/packages.txt` or `platform/macos/Brewfile`, not into a setup script. Adding something to one list does **not** imply adding it to the other; see the "why these lists are separate" note in each file.
- To add a git persona: run `hat add <name>` (or manually create `utilities/git-hat/personas/<name>.conf` with `NAME`/`EMAIL`/`KEY`/`DIR` and run `hat sync`) — that regenerates the `github-<name>` ssh alias and the `includeIf` identity mapping. The persona's `DIR` doubles as both the `includeIf` match and the `hat clone` destination root. To delete one: `hat remove <name>` (confirmation-gated; never touches the persona's DIR).
- keyd configs live in `platform/linux/keyd/*.conf` (symlinked into `/etc/keyd/` by the Linux setup — Linux-only, which is why they are not under `common/`). A new `*.conf` there needs a re-run of `install.sh` (or a manual `sudo ln -sf`) to be linked; content edits to already-linked files are live immediately but need `sudo keyd reload` to take effect.
- `*.pub` files are gitignored alongside private keys — SSH keys themselves are never committed; `ssh_config` only references key paths.
- macOS is implemented but has **not been run on a real Mac** — it is verified only by a sandboxed dual-branch run of `install.sh` with stubbed `brew`/`sudo`. Expect to shake out Homebrew-prefix and permission details on first real use.
- The Codex CLI is deliberately not auto-installed by `common/install-agents.sh` (its distribution channel differs per platform and changes often); `codex-sync` writes the config regardless, so the CLI can arrive later.
