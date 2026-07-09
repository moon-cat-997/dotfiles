# git-hat

Pick the right Git identity and SSH key **automatically, by directory**. No more
remembering which `git@github-…:` host to type, or which email a repo should use.

You keep several GitHub accounts. Each root under `~/Projects` belongs to one of
them. `git-hat` makes the folder a repo lives in decide the commit identity
(name/email) and the SSH key used to push — and lets you clone straight from a
pasted GitHub URL without rewriting the host.

```console
$ cd ~/Projects/JuliusAgency
$ hat clone git@github.com:JuliusAgency/some-repo.git
Cloning as 'office': git@github-office:JuliusAgency/some-repo.git
```

## Install

Installed by the dotfiles `install.sh`, which:

1. symlinks `git-hat` into `~/bin` as both `git-hat` and `hat`,
2. symlinks `config-files/gitconfig` → `~/.gitconfig` and `config-files/ssh_config` → `~/.ssh/config`,
3. runs `hat sync` to generate the per-persona configs.

```bash
cd ~/dotfiles && ./install.sh
```

`~/bin` must be on `$PATH`. Because the executable is named `git-hat`, it also
works as a Git subcommand: `git hat whoami`.

## Commands

| Command | What it does |
|---|---|
| `hat whoami [path]` | Print the persona for the current dir (or `path`). |
| `hat clone <git-url>` | Clone into `$PWD` using the persona of `$PWD`, rewriting the URL host to `github-<persona>`. Accepts `git@github.com:org/repo.git` and `https://github.com/org/repo.git`. |
| `hat sync` | Regenerate `generated/` (ssh aliases + git identities) from `personas/*.conf`. Also creates each persona's `DIR` and warns about missing SSH keys. |
| `hat keygen` | Generate an ed25519 key for every persona whose `KEY` file is missing, then offer to upload the public key to GitHub via `gh ssh-key add`. |
| `hat doctor` | Health check: `gh` installed & authenticated, generated configs present, and per persona — `DIR` exists, `KEY` exists, and a live `ssh -T` auth test showing which GitHub account the key actually maps to. |

## New machine bootstrap

The repo carries all the *logic*, but not the *secrets* — private SSH keys are
git-ignored by design, and GitHub cannot give them back (it only stores public
keys). On a fresh machine:

```bash
# 1. First clone must be HTTPS — no keys or gh exist yet.
#    The path must be exactly ~/dotfiles.
git clone https://github.com/<you>/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install.sh        # links configs, installs gh, runs `hat sync`

# 2. Authenticate gh (HTTPS credential helper depends on it)
gh auth login

# 3. Keys: either copy them from the old machine (chmod 600), or generate new:
hat keygen                           # creates missing keys, offers pubkey upload

# 4. Verify everything end to end
hat doctor
```

`hat keygen` uploads each public key via `gh ssh-key add` — mind that `gh` is
logged into **one** account at a time while personas map to different accounts;
use `gh auth switch` (or the printed manual command) per account. Uploading
needs the `admin:public_key` scope (`gh auth refresh -s admin:public_key`).

## Configuration

A **persona** is one GitHub identity, declared once as a sourced shell file in
`personas/<name>.conf`:

```bash
NAME="Ada Lovelace"                 # git user.name
EMAIL="ada@example.com"             # git user.email
KEY="$HOME/.ssh/id_ada"            # SSH private key for this account
DIR="$HOME/Projects/Personal"      # root directory this identity owns
```

`DIR` does double duty: it is both the `includeIf` match (which repos get this
identity) and the destination root that `hat clone` treats as belonging to the
persona. The file name (`<name>`) becomes the SSH host alias `github-<name>`.

### Add a persona

1. Create `personas/<name>.conf` with the four fields above.
2. Run `hat sync`.

That regenerates the `github-<name>` SSH alias and the `includeIf` identity
mapping. Nothing else to edit.

## How it works

`personas/*.conf` is the **single source of truth**. `hat sync` derives
everything else from it:

```
personas/*.conf ──sync──▶ generated/ ──include──▶ config-files/ ──symlink──▶ ~
   (edit here)            (derived)      (static base)
```

- `generated/ssh_config` — a `Host github-<persona>` block per persona → its `KEY`.
- `generated/gitconfig-<persona>` — `[user]` name/email per persona.
- `generated/gitconfig-includes` — `includeIf "gitdir:<DIR>/"` → the matching identity file.

The checked-in static bases pull the generated output in:

- `config-files/gitconfig` → `~/.gitconfig`: static settings (`alias`, `init`,
  `credential`) + a default (personal) identity + `include` of the generated
  includes. Repos in a persona directory override the default.
- `config-files/ssh_config` → `~/.ssh/config`: an `Include` of the generated
  ssh aliases.

Directory matching is boundary-aware: `~/Projects/Own-old` does **not** match a
persona whose `DIR` is `~/Projects/Own` (the trailing `/` in `gitdir:<DIR>/`
prevents the prefix collision).

`generated/` is git-ignored — it is derived output, regenerated by `hat sync`
(and by `install.sh` on every run). **Never** hand-edit `generated/` or put
identities back into `config-files/`; edit `personas/` and re-sync.

## Layout

```
utilities/git-hat/
├── git-hat            # dispatcher (whoami / clone / sync / keygen / doctor)
├── personas/          # source of truth — one *.conf per identity
├── config-files/      # static bases, symlinked into ~ (gitconfig, ssh_config)
├── generated/         # derived by `hat sync` (git-ignored)
└── README.md
```
