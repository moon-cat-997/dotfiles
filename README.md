# 🛠 dotfiles

A personal repository of configuration files and helper scripts for automatically setting up a development environment on **Linux** and **macOS**.

> 📁 This repository is intended to be cloned directly into your **home directory** as `~/dotfiles`.

---

## 📦 Features

- One-command environment setup via `install.sh`
- Separate Git configurations for personal and work contexts
- Zsh and SSH client configuration
- Git helper scripts (`git-whoami`, `clone-*`)
- System update script for Linux
- Platform-specific setup (Linux and macOS)

---

## 🚀 Installation

```bash
cd ~/dotfiles
./install.sh
```

This will:

- Create symbolic links for configuration files in your home directory
- Make all scripts executable and link them into `~/bin`
- Run platform-specific setup depending on your OS

 !TODO add this to the script 
Additionaly two ssh-keys are necessary to create. Their names are: id_kotikobormotik and id_wandel812 with the emails correspondenly
```bash
ssh-keygen -t ed25519 -C "ivanovdm812@gmail.com"
```

---

## 🗂 Structure

```
dotfiles/
├── common/             # Shared configuration files
│   ├── gitconfig
│   ├── gitconfig-personal
│   ├── gitconfig-work
│   ├── ssh_config
│   └── zshrc
├── git-scripts/        # Git-related utility scripts
│   ├── clone-personal.sh
│   ├── clone-work.sh
│   └── git-whoami.sh
├── linux/              # Linux-specific setup and tools
│   ├── linux-setup.sh
│   └── update-system.sh
├── macos/              # macOS-specific setup (optional)
│   └── macos-setup.sh
├── install.sh          # Main installation script
└── README.md
```

---

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
git-whoami
```

### Clone repositories:
```bash
clone-personal
clone-work
```

> All helper scripts from `git-scripts/` are symlinked into `~/bin` and available globally.

---

## 🔧 Git Identity Management

This setup uses conditional includes in `.gitconfig` to switch Git identity based on directory:

- Projects under `~/Projects/JuliusAgency` → use `gitconfig-work`
- Projects under `~/Projects/Own` → use `gitconfig-personal`

This is achieved via:

```gitconfig
[includeIf "gitdir:~/Projects/JuliusAgency/"]
    path = ~/.gitconfig-work
[includeIf "gitdir:~/Projects/Own/"]
    path = ~/.gitconfig-personal
```

---

## 🐧 Supported Platforms

- ✅ Linux (tested on Manjaro)
- ⚠️ macOS (basic support, work in progress)

---

## 📌 Notes

- Make sure `~/bin` is in your `$PATH`
- All `.sh` files in `git-scripts/` are made executable during installation
- Aliases and environment variables are set in `zshrc` under `common/`

---

## 🧩 Planned Improvements

- Auto-install of Zsh plugins and fonts
- Homebrew integration on macOS
- Automatic backup of existing config files before linking
- Dotfiles version detection and self-update logic
