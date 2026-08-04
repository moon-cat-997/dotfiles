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

### Dependencies

Both are declared in `platform/linux/packages.txt` and `platform/macos/Brewfile`,
so `install.sh` brings them in. `hat doctor` reports either one missing.

| Tool | Needed for | Without it |
|---|---|---|
| `gh` | HTTPS credentials (`config-files/gitconfig` delegates to `gh auth git-credential`), and `hat keygen`'s public-key upload | HTTPS pushes prompt for a password; `keygen` prints the manual `gh ssh-key add` command instead |
| `direnv` | Loading each persona's generated `.envrc` — see [CLI account tokens](#cli-account-tokens). Needs `eval "$(direnv hook zsh)"` in the shell rc (already in `common/zshrc`) | `hat sync` still writes the `.envrc`, but nothing reads it: every CLI silently stays on its global login, i.e. the wrong account |

`direnv` is required only by personas that declare `TOKENS=`; git and SSH identity
selection works without it.

## Commands

| Command | What it does |
|---|---|
| `hat whoami [path]` | Print the persona for the current dir (or `path`) with its identity: `personal — Name <email> (git@github-personal)`. For the *live* GitHub login of the key, see `hat doctor`. |
| `hat clone <git-url>` | Clone into `$PWD` using the persona of `$PWD`, rewriting the URL host to `github-<persona>`. Accepts `git@github.com:org/repo.git` and `https://github.com/org/repo.git`. |
| `hat remote-add <git-url> [name]` | Add a remote (default `origin`) to the current repo under the persona alias of its directory — the one-step form of GitHub's suggested `git remote add origin git@github.com:org/repo.git` for an existing local repo. Same URL forms as `hat clone`; fails if the remote name already exists (use `hat adopt` for that). |
| `hat adopt` | Fix a repo acquired *without* `hat clone`: rewrite **all** GitHub remotes (`github.com`, https, or a wrong `github-<persona>` alias) to the persona of the repo's directory. Non-GitHub remotes are left alone. Idempotent. |
| `hat add <name>` | Create a persona interactively: prompts for name/email/key/dir (with defaults derived from `<name>`), writes `personas/<name>.conf`, runs `hat sync`, and offers `hat keygen`. Warns if the dir overlaps another persona's `DIR`. |
| `hat remove <name>` | Delete a persona after a confirmation prompt. Shows a preflight report first: repos in its `DIR` whose remotes point at the vanishing `github-<name>` alias, and a reminder that leftover repos fall back to the default identity. The `DIR` is never touched; the SSH key is deleted only on separate explicit consent (the public key on GitHub stays either way). |
| `hat sync` | Regenerate `generated/` (ssh aliases + git identities) from `personas/*.conf`. Also creates each persona's `DIR`, warns about missing SSH keys, and writes the `.envrc` for personas that declare `TOKENS=`. |
| `hat keygen` | Generate an ed25519 key for every persona whose `KEY` file is missing, then offer to upload the public key to GitHub via `gh ssh-key add`. |
| `hat token list` | Print the known CLI account tokens: variable → CLI → the command `doctor` verifies it with. |
| `hat token set <persona> <VAR>` | Store a CLI access token for a persona at `~/.config/hat/<persona>/<VAR>` (mode 600). Prompts without echoing — the token is never accepted as an argument, which would put it in shell history. See [CLI account tokens](#cli-account-tokens). |
| `hat doctor` | Health check: `gh` installed & authenticated, generated configs present, and per persona — `DIR` exists, `KEY` exists, and a live `ssh -T` auth test showing which GitHub account the key actually maps to. For personas with `TOKENS=`, also: `.envrc` present, each token file readable and mode 600, and a live identity check per CLI (`eas whoami`, …). |

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

```console
$ hat add freelance
```

Prompts for the four fields (with defaults derived from the name), writes the
conf, runs `hat sync`, and offers to generate the SSH key. Equivalent manual
flow: create `personas/<name>.conf` with the four fields above and run
`hat sync` — that regenerates the `github-<name>` SSH alias and the `includeIf`
identity mapping. Nothing else to edit.

### Remove a persona

```console
$ hat remove freelance
```

Asks for confirmation, then deletes the conf and re-syncs (`hat sync` purges
the generated configs of removed personas by design). Before confirming it
lists repos in the persona's `DIR` whose remotes still point at the
`github-<name>` alias — those must be moved and `hat adopt`-ed under another
persona, or they will break. The `DIR` and its contents are never deleted; the
SSH key is only deleted if you separately agree, and the public key uploaded to
GitHub must be revoked there manually.

## CLI account tokens

Every SaaS CLI stores **one** global login: `eas` and `expo` share
`~/.expo/state.json`, `supabase` uses `~/.supabase`, `gh` keeps its accounts in
the system keyring. Logging in as a second account logs the first one out, so a
work account and a personal side project fight over the same slot.

All of them also accept an **access token in an environment variable**, which
takes precedence over the stored login — that path exists so CI can run without
an interactive login. It makes the account selectable per directory, which is
exactly what `git-hat` already does for git and SSH.

### How it fits the persona

A persona gains one optional field naming the tokens that identity owns:

```bash
NAME="Ada Lovelace"
EMAIL="ada@example.com"
KEY="$HOME/.ssh/id_ada"
DIR="$HOME/Projects/Personal"
TOKENS="EXPO_TOKEN SUPABASE_ACCESS_TOKEN"    # ← the entire configuration
```

`hat sync` writes `$DIR/.envrc`, and [direnv](https://direnv.net) exports those
variables when you `cd` into the tree and **unexports them on the way out**.
That unloading is the whole reason direnv is a dependency instead of a
hand-rolled shell hook: a variable that leaked out of `~/Projects/Own` would
silently make `eas build` in a work project run as the personal account.

### Which token belongs to which CLI

Nothing has to decide — the **variable name is the binding**. `eas` reads
`EXPO_TOKEN`, the Supabase CLI reads `SUPABASE_ACCESS_TOKEN`; each hardcodes the
name it answers to, so `hat` only delivers the value and never routes it.

The one thing it must catch is a **typo**, because that fails silently: write
`EXPO_ACCESS_TOKEN` and nothing errors — no CLI reads it, and `eas` quietly
falls back to the global `~/.expo` session, i.e. the wrong account. So `sync`
validates every `TOKENS=` entry against a known table, and `doctor` checks the
identity that actually resolves:

| Variable | CLI | Verified with |
|---|---|---|
| `EXPO_TOKEN` | `eas`, `expo` | `eas whoami` |
| `SUPABASE_ACCESS_TOKEN` | `supabase` | `supabase projects list` |
| `GH_TOKEN` | `gh` | `gh auth status` |

`hat token list` prints it; supporting another CLI is one row.

### Secrets

Tokens are **never** committed — the same rule as the SSH keys. One file per
variable at `~/.config/hat/<persona>/<VAR>`, mode `600`; the generated `.envrc`
holds only the path, wrapped in a guard so a missing file warns once instead of
erroring on every `cd`:

```bash
# generated by hat sync — do not edit
_hat_token() {
  if [ -r "$2" ]; then export "$1=$(cat "$2")"
  else echo "hat: $1 not set — run: hat token set personal $1" >&2; fi
}
_hat_token EXPO_TOKEN "$HOME/.config/hat/personal/EXPO_TOKEN"
unset -f _hat_token
```

Write them with `hat token set <persona> <VAR>` — it prompts without echoing,
creates the directory and sets the mode. There is no `keygen` equivalent here:
neither Expo nor Supabase can mint a token from the CLI, so create it in the
browser (expo.dev → Access Tokens; supabase.com → Account → Access Tokens) and
paste it in.

### One identity per persona directory

Everything under a persona's `DIR` shares **one** account per CLI. That is the
design, not a limitation — the directory *is* the identity. If a single project
ever needs different credentials, drop a nested `.envrc` inside that project:
direnv layers children over parents, so it overrides only what it redefines and
inherits the rest.

### Gotchas

- `$DIR/.envrc` is **generated**. `hat sync` overwrites it — never hand-edit it;
  change `TOKENS=` and re-sync. It is also the only file `hat` writes outside
  the dotfiles repo.
- direnv refuses to load an `.envrc` until it is approved, so `hat sync` runs
  `direnv allow` for the files it generates.
- Never shell out inside the generated `.envrc` (e.g. `gh auth token`): direnv
  re-executes it on every entry into the tree, so a subprocess there is a stall
  on every `cd`. Reading a static file with `cat` is instant.
- `GH_TOKEN` also decides which account `gh auth git-credential` serves, because
  `config-files/gitconfig` delegates HTTPS credentials to `gh`. Harmless while
  remotes are SSH, but it is a real interaction with an existing part of the
  setup — add `GH_TOKEN` only after the others work.

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
├── git-hat            # dispatcher (whoami / clone / remote-add / adopt / add / remove / sync / keygen / doctor)
├── personas/          # source of truth — one *.conf per identity
├── config-files/      # static bases, symlinked into ~ (gitconfig, ssh_config)
├── generated/         # derived by `hat sync` (git-ignored)
└── README.md
```
