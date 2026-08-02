# Neovim cheatsheet — coming from VSCode

`<leader>` is **Space**. Press it alone and wait: a menu of what's available pops up
(which-key). That menu is the real cheatsheet — this file is the short version.

## The five you need on day one

| Keys | What it does | VSCode equivalent |
|---|---|---|
| `<leader><space>` | Find file by name | `Ctrl+P` |
| `<leader>/` | Search text across the project | `Ctrl+Shift+F` |
| `<leader>e` | Toggle file tree | `Ctrl+B` |
| `<leader>gg` | Git UI (lazygit) | Source Control panel |
| `<C-/>` | Toggle a terminal | `` Ctrl+` `` |

## Moving through code

| Keys | What it does |
|---|---|
| `gd` | Go to definition |
| `gr` | Find all references |
| `K` | Show type / docs under cursor (hover) |
| `<C-o>` / `<C-i>` | Jump back / forward through your jump history |
| `<leader>ss` | Jump to a symbol in this file (function, class) |
| `]d` / `[d` | Next / previous diagnostic (error or warning) |

## Changing code

| Keys | What it does |
|---|---|
| `<leader>ca` | Code action (auto-import, quick fix) |
| `<leader>cr` | Rename symbol everywhere |
| `<leader>cf` | Format the file |
| `<leader>cd` | Show the full error message on this line |

## Buffers and windows

An open file is a *buffer*. There is no tab bar you must obey — buffers are just a list.

| Keys | What it does |
|---|---|
| `<S-h>` / `<S-l>` | Previous / next buffer |
| `<leader>bd` | Close this buffer |
| `<leader>-` / `<leader>\|` | Split horizontally / vertically |
| `<C-h/j/k/l>` | Move between splits |

## Markdown

| Keys | What it does |
|---|---|
| `<leader>m` | Toggle rendered preview ↔ raw markup |

## Maintenance

| Command | What it does |
|---|---|
| `:Lazy` | Plugin manager — install, update, check load times |
| `:LazyExtras` | Turn language support on/off (`x` toggles). **This is how you add a language.** |
| `:Mason` | Language servers, formatters, linters — install/update |
| `:LazyHealth` | Diagnose a broken setup. Read `ERROR` lines; warnings are usually fine. |
| `:checkhealth lsp` | Why isn't the language server attaching to this file? |

After `:LazyExtras` or a plugin update, commit the changed `lazyvim.json` /
`lazy-lock.json` — that is what carries the setup to another machine.

## Gotchas specific to this machine

- **Node version switching (nvm).** JS/TS language servers are installed by Mason under
  `~/.local/share/nvim`. If you `nvm use` a different major version and TypeScript support
  goes quiet, reinstall it: `:MasonInstall vtsls` (and `eslint-lsp`, `prettier`).
- **C++ needs `compile_commands.json`** to resolve includes. Generate it with
  `cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON …` and symlink it into the project root,
  otherwise clangd will flag valid headers as missing.
- **This config is a symlink** to `~/dotfiles/common/nvim`. Editing it edits the repo —
  run `git status` in `~/dotfiles` after any big change.

## Rollback

The pre-LazyVim setup is intact. To go back:

```bash
rm ~/.config/nvim                      # removes the symlink only, not the repo
mv ~/.config/nvim.bak       ~/.config/nvim
mv ~/.local/share/nvim.bak  ~/.local/share/nvim
mv ~/.local/state/nvim.bak  ~/.local/state/nvim
mv ~/.cache/nvim.bak        ~/.cache/nvim
```

Then drop the `ln -sfn ~/dotfiles/common/nvim` line from `install.sh` so a re-run
doesn't put it back.

## Learning vim itself

Run `:Tutor` inside nvim — 30 minutes, built in, and the best return on time here.
