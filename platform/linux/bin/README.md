# update-system

Full system update for Manjaro/Arch in one command:

1. **Official packages** — `sudo pacman -Syu`
2. **AUR packages** — `yay -Sua`

## Usage

```bash
update-system
```

The script is symlinked into `~/bin` as `update-system` by `install.sh`
(like every `*.sh` under `linux/`), so it is available globally.

It runs with `set -e` and will stop at the first failing step.

The sudo password is asked **once at the start** (`sudo -v`) and a
background keepalive refreshes the timestamp for the whole run, so long
downloads/builds never re-prompt. `yay` is used for the AUR instead of
`pamac` because yay authenticates via sudo (covered by the upfront
prompt), while pamac uses polkit and would ask for the password again
mid-run.

`yay` itself is installed by `linux-setup.sh` during `install.sh` (from
Manjaro's repos, or built from the AUR on vanilla Arch), so the script
works out of the box after an install; it exits with a clear error if
yay is missing.
