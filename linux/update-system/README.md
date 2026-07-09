# update-system

Full system update for Manjaro/Arch in one command:

1. **Official packages** — `sudo pacman -Syu`
2. **AUR packages** — `pamac upgrade --aur`

## Usage

```bash
update-system
```

The script is symlinked into `~/bin` as `update-system` by `install.sh`
(like every `*.sh` under `linux/`), so it is available globally.

It runs with `set -e` and will stop at the first failing step. `pacman`
prompts for `sudo`; `pamac` handles AUR authentication itself.
