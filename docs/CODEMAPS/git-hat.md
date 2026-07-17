<!-- Generated: 2026-07-17 | Files scanned: git-hat (613 lines), personas/, config-files/ | Token estimate: ~800 -->

# git-hat — per-directory git identity

`utilities/git-hat/git-hat` (613 lines): dispatcher symlinked as `git-hat`, `hat`, and usable as `git hat`.
Personas are the single source of truth; ssh aliases + git identities are **generated**, not hand-written.

## Data flow

```
personas/<name>.conf  (NAME, EMAIL, KEY, DIR)   ← source of truth
        │  hat sync
        ▼
generated/  (gitignored, wired-in live)
   ├── ssh_config          Host github-<name> → IdentityFile KEY
   ├── gitconfig-<name>    [user] name/email
   └── gitconfig-includes  [includeIf "gitdir:DIR/"] → gitconfig-<name>
        ▲                                    ▲
config-files/ssh_config  ──Include──┘        │
config-files/gitconfig   ──include──────────┘  (+ static alias/init/credential, default personal identity)
        │  install.sh ln -sf
        ▼
   ~/.ssh/config , ~/.gitconfig
```

Identity is selected automatically by directory via generated `includeIf` blocks.
Each persona → ssh host alias `github-<name>` bound to that persona's `KEY`.

## Personas (personas/*.conf)

| name | DIR | identity |
|---|---|---|
| personal | ~/Projects/Own | moon-cat-997 |
| office | ~/Projects/JuliusAgency | Dmitriy Ivanov (jleprog0) |
| work | ~/Projects/Own-old | Dmitriy Ivanov (ivnaovdm812) |

Default (anywhere else) → personal.

## Commands (dispatch in `main`)

```
clone <url>              cmd_clone       clone into $PWD, host→github-<persona of cwd>
remote-add <url> [name]  cmd_remote_add  add remote (default origin) under dir's persona alias
adopt                    cmd_adopt       rewrite all GitHub remotes of repo → its dir's persona
whoami [path]            cmd_whoami      print persona + identity for path (default $PWD)
add <name>               cmd_add         interactive conf create (defaults from name) + sync + keygen offer
remove <name>            cmd_remove      confirm-gated delete: preflight broken-remote scan, conf rm + sync; DIR kept
sync                     cmd_sync        regenerate generated/ from personas/, mkdir DIRs
keygen                   cmd_keygen      ed25519 per persona w/ missing KEY, offer gh upload
doctor                   cmd_doctor      gh auth, configs, per-persona dir/key/live ssh -T
```

## Key helpers

```
persona_for_path <path>  longest-DIR-prefix match, boundary-aware (Own-backup ≠ Own)
parse_org_repo <url>     org/repo from scp | https | ssh:// forms
url_host <url>           host portion (github.com vs github-<persona>)
load_persona <name>      source personas/<name>.conf → NAME/EMAIL/KEY/DIR
ask <prompt> [default]   read value; rejects chars unsafe in sourced conf ($ " ` \)
to_home_var <path>       ~/… or /home/…/… → literal $HOME/… (portable conf form)
```

## Rules

- Never hand-edit `generated/` or put identities back in `config-files/`; edit `personas/*.conf` + `hat sync`.
- Keys are gitignored (`*.pub` too); fresh machine → `hat keygen`.
- HTTPS creds delegated to `gh auth git-credential` — `gh` must be installed + authenticated.
- Use `hat clone` / `hat remote-add` (not raw git) to keep host alias + directory consistent; `hat adopt` fixes after the fact.
