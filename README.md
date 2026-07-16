# 🛠 dotfiles

A personal repository of configuration files and helper scripts for automatically setting up a development environment on **Linux** and **macOS**.

> 📁 This repository is intended to be cloned directly into your **home directory** as `~/dotfiles`.

---

## 📦 Features

- One-command environment setup via `install.sh`
- Multiple Git identities picked **automatically by directory** via [`git-hat`](utilities/git-hat/README.md)
- Zsh and SSH client configuration
- Claude Code setup synced across machines (settings, statusline, skills, hooks, rules)
- Helper scripts (`hat`, `update-system`)
- Platform-specific setup (Linux; macOS is a stub)

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
- Run platform-specific setup depending on your OS (on Linux: installs packages
  incl. `gh`, `keyd`, `yay`, and Claude Code; symlinks `common/keyd/*.conf`
  into `/etc/keyd` and enables the `keyd` service)

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
│   ├── claude/             # Claude Code configs, symlinked into ~/.claude
│   │   ├── settings.json   # statusline, hooks, permissions, plugins
│   │   ├── CLAUDE.md       # global instructions
│   │   ├── statusline-command.sh
│   │   ├── hooks/ scripts/ skills/ commands/ rules/
│   └── keyd/               # keyd remapping configs, symlinked into /etc/keyd (Linux)
│       ├── default.conf
│       └── mice.conf
├── linux/                  # Linux-specific setup and tools
│   ├── linux-setup.sh
│   └── update-system/      # full pacman + AUR system update (see its README)
│       ├── update-system.sh
│       └── README.md
├── macos/                  # macOS-specific setup (stub)
│   └── macos-setup.sh
├── utilities/
│   └── git-hat/            # directory-based git identity manager (see its README)
│       ├── git-hat         # dispatcher (whoami / clone / sync / keygen / doctor)
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
- ⚠️ macOS (basic support, work in progress)

---

## 📌 Notes

- Make sure `~/bin` is in your `$PATH`
- All `.sh` files in `linux/` are made executable during installation
- Aliases and environment variables are set in `zshrc` under `common/`
- `common/keyd/*.conf` are symlinked into `/etc/keyd`, so editing them in the
  repo changes the live config — apply with `sudo keyd reload`
- Private SSH keys are never committed; regenerate them with `hat keygen`

---

## 🧩 Planned Improvements

- Ask about username instead of hardcoding `/home/dmitriy`
- Auto-install of Zsh plugins and fonts
- Homebrew integration on macOS
- Automatic backup of existing config files before linking
- Dotfiles version detection and self-update logic
