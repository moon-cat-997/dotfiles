# 🛠 dotfiles

A personal repository of configuration files and helper scripts for automatically setting up a development environment on **Linux** and **macOS**.

> 📁 This repository is intended to be cloned directly into your **home directory** as `~/dotfiles`.

---

## 📦 Features

- One-command environment setup via `install.sh`
- Multiple Git identities picked **automatically by directory** via [`git-hat`](utilities/git-hat/README.md)
- Zsh and SSH client configuration
- Neovim configured as an IDE (LazyVim) for TypeScript/React, Python and C++
- Claude Code setup synced across machines (settings, statusline, skills, hooks, rules)
- Codex setup synced across machines with a native baseline (AGENTS.md, selected skills, MCP defaults)
- Helper scripts (`hat`, `update-system`)
- Platform-specific setup split under `platform/` (Linux and macOS, separate package lists)

---

## 🚀 Installation

```bash
# First clone on a fresh machine must be HTTPS — no SSH keys exist yet
git clone https://github.com/moon-cat-997/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

This will:

- Create symbolic links for configuration files in your home directory
- Make all scripts executable and link them into `~/bin`
- Run `hat sync` to generate per-persona git/ssh configs (and create the persona directories)
- Run platform-specific setup depending on your OS — `platform/linux/setup.sh`
  (pacman packages from `packages.txt`, `yay`, keyd into `/etc/keyd`) or
  `platform/macos/setup.sh` (Homebrew + `Brewfile`)
- Install the agent CLIs, then apply the Claude and Codex configs
  (`claude-sync`, `codex-sync`)

On a **new machine**, finish the bootstrap with:

```bash
gh auth login    # HTTPS credentials are delegated to gh
hat keygen       # generate missing per-persona SSH keys, upload pubkeys via gh
hat doctor       # verify: gh, keys, dirs, live ssh auth per persona
```

See [utilities/git-hat/README.md](utilities/git-hat/README.md) for the full bootstrap details.

---

## 🗂 Structure

```
dotfiles/
├── common/                 # Shared configuration files
│   ├── zshrc
│   ├── nvim/               # LazyVim config, symlinked to ~/.config/nvim
│   │   ├── init.lua
│   │   ├── lua/config/     # options, keymaps, autocmds, lazy bootstrap
│   │   ├── lua/plugins/    # per-plugin overrides (markdown, …)
│   │   ├── lazyvim.json    # which LazyVim "extras" (language bundles) are on
│   │   ├── lazy-lock.json  # plugin versions pinned to exact commits
│   │   └── CHEATSHEET.md   # keybindings + rollback
│   ├── claude/             # Claude Code configs, symlinked into ~/.claude
│   │   ├── settings.json   # statusline, hooks, permissions, plugins
│   │   ├── CLAUDE.md       # global instructions
│   │   ├── statusline-command.sh
│   │   ├── hooks/ scripts/ skills/ commands/ rules/
│   ├── codex/              # Codex baseline synced into ~/.codex
│   │   ├── config.toml     # managed baseline merged into live config
│   │   ├── AGENTS.md       # global instructions
│   │   ├── codex-sync.sh
│   │   └── skills/
│   └── install-agents.sh   # installs the agent CLIs — same on both OSes
├── platform/               # everything OS-specific lives here
│   ├── linux/
│   │   ├── setup.sh        # pacman, yay, keyd, login shell
│   │   ├── packages.txt    # the pacman package list
│   │   ├── keyd/           # remapping configs, symlinked into /etc/keyd
│   │   │   ├── default.conf
│   │   │   └── mice.conf
│   │   └── bin/            # Linux-only commands, linked into ~/bin
│   │       ├── update-system.sh   # full pacman + AUR update (see its README)
│   │       └── README.md
│   └── macos/
│       ├── setup.sh        # Xcode CLT, Homebrew, login shell
│       └── Brewfile        # the brew package list
├── utilities/
│   └── git-hat/            # directory-based git identity manager (see its README)
│       ├── git-hat         # dispatcher (whoami / clone / remote-add / adopt / sync / keygen / doctor)
│       ├── personas/       # source of truth — one *.conf per identity
│       ├── config-files/   # static bases symlinked into ~ (gitconfig, ssh_config)
│       └── generated/      # derived by `hat sync` (git-ignored)
├── install.sh              # Main installation script
└── README.md
```

## ⚙️ Usage

### Run the setup script:
```bash
./install.sh
```

### Update your system (Linux):
```bash
update-system
```

### Check which Git identity is in use:
```bash
hat whoami      # persona for the current directory: name, email, ssh alias
```

### Clone repositories with the right identity:
```bash
cd ~/Projects/Own
hat clone git@github.com:org/repo.git   # clones via the persona's SSH alias
```

### Add a remote to an existing local repo:
```bash
cd ~/Projects/Own/my-repo
# GitHub suggests `git remote add origin git@github.com:org/repo.git` — use this instead:
hat remote-add git@github.com:org/repo.git   # adds origin via the persona's SSH alias
```

### Fix a repo cloned without `hat clone`:
```bash
cd ~/Projects/Own/some-repo
hat adopt   # rewrites its GitHub remotes to the dir's persona alias
```

> All helper scripts are symlinked into `~/bin` and available globally.

---

## 🔧 Git Identity Management

Identity is selected **by directory**: each persona in
`utilities/git-hat/personas/<name>.conf` declares a `DIR`, and `hat sync`
generates the `includeIf "gitdir:..."` blocks and `github-<name>` SSH aliases
from it. Everything outside a persona directory defaults to personal.

- `~/Projects/Own/**` → personal
- `~/Projects/JuliusAgency/**` → office
- `~/Projects/Own-old/**` → work (deprecated account)

Details: [utilities/git-hat/README.md](utilities/git-hat/README.md).

---

## 🐧 Supported Platforms

- ✅ Linux (tested on Manjaro)
- ⚠️ macOS (implemented, but not yet run on a real Mac — verified only in a sandboxed dual-branch install)

---

## 📌 Notes

- Make sure `~/bin` is in your `$PATH`
- All `.sh` files in `git-scripts/` and `platform/<os>/bin/` are made executable and linked into `~/bin` during installation. OS-specific ones are linked only by their own platform.
- Aliases and environment variables are set in `zshrc` under `common/`
- `platform/linux/keyd/*.conf` are symlinked into `/etc/keyd`, so editing them in the
  repo changes the live config — apply with `sudo keyd reload`
- `common/nvim/` is symlinked to `~/.config/nvim`, so edits there are live in the editor
  immediately. Downloaded plugins and language servers live in `~/.local/share/nvim` and are
  **not** tracked — a first `nvim` launch on a new machine installs them, pinned by the
  committed `lazy-lock.json`. See [common/nvim/CHEATSHEET.md](common/nvim/CHEATSHEET.md).
- Private SSH keys are never committed; regenerate them with `hat keygen`

---

## 🧩 Planned Improvements

- ~~Ask about username instead of hardcoding `/home/dmitriy`~~ — done: all paths are `~`-relative
- Auto-install of Zsh plugins and fonts
- ~~Homebrew integration on macOS~~ — done: `platform/macos/Brewfile`
- Automatic backup of existing config files before linking
- Dotfiles version detection and self-update logic
