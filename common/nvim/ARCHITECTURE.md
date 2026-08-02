# How this Neovim config works

Keybindings live in [CHEATSHEET.md](CHEATSHEET.md). This file is the mental model:
what the moving parts are, so a breakage is diagnosable instead of mysterious.

**The short version:** Neovim is just an editor. The "IDE" features come from
separate background programs it talks to over standard protocols. This config is
mostly wiring, plus decisions about *when* to load things.

---

## 1. Where the files live

```
~/.config/nvim  ──symlink──▶  ~/dotfiles/common/nvim/   (tracked in git)
                                        │
~/.local/share/nvim/  ◀── downloaded ───┘  plugins + language servers
                          (NOT tracked — rebuilt on any machine)
```

Neovim reads its config from `~/.config/nvim`. That path is a symlink into this
repo, so there is only one copy of each file — editing either path edits the same
bytes, and no sync step exists or is needed.

The tracked/untracked split is deliberate:

- **Tracked:** `init.lua`, `lua/`, `lazyvim.json`, `lazy-lock.json`, `stylua.toml`,
  `.neoconf.json` — small, portable, meaningful in a diff.
- **Untracked:** `~/.local/share/nvim` (plugins, language-server binaries, ~25 MB),
  `~/.local/state/nvim` (undo history, sessions), `~/.cache/nvim`.

`lazy-lock.json` bridges the two: it pins every plugin to an exact git commit, so a
second machine downloads *identical* versions rather than whatever is current
upstream. It is the `package-lock.json` of this setup — commit it after any plugin
change.

---

## 2. The layer stack

Each layer narrows the one below it:

```
Neovim            the editor. Knows nothing about TypeScript.
  └─ lazy.nvim    plugin manager: downloads plugins, decides when to load each
      └─ LazyVim  a "distro" — ~46 plugins pre-wired to work together
          └─ extras          opt-in language bundles (13 enabled)
              └─ your files  lua/config/*, lua/plugins/*  ← the only part you own
```

`init.lua` is three lines; it loads `lua/config/lazy.lua`, which starts the plugin
manager and hands it a list: *LazyVim's plugins, then mine*. Later entries win.
That ordering is what makes overriding possible at all.

**How extras get in.** `lazyvim.json` is a plain list of module names. LazyVim's
`plugins/xtras.lua` iterates that list and turns each name into a plugin import. So
`:LazyExtras` is not magic — it rewrites that JSON, and the list becomes imports on
the next start. This is why the file is committed: it *is* the language config.

---

## 3. What actually makes it an IDE

Three independent engines. In VSCode these are hidden; here they are separate and
individually diagnosable, which is the main practical difference.

### LSP — Language Server Protocol

A *language server* is a standalone program that reads your project and answers
questions: where is this defined, what type is this, what is wrong on line 12.
`vtsls` serves TypeScript, `clangd` serves C++, `basedpyright` serves Python.

They are not Neovim plugins. They are separate processes; the editor starts one and
talks to it over a documented protocol. VSCode uses the same servers over the same
protocol — Microsoft designed it — which is why `gd` behaves identically in both.

### Treesitter

Parses each file into a real syntax tree as you type, used for accurate highlighting
and structural motions ("select inside this function"). Older editors highlighted
with regular expressions, which guess badly on anything nested.

Each language's parser is C code compiled on this machine, which is why the
`tree-sitter` CLI is a hard requirement — without it, parser installation fails and
highlighting quietly falls back to nothing.

### Mason

A package manager for the two above. Language servers are written in many languages
(`vtsls` is JavaScript, `basedpyright` is Python, `clangd` is C++), so Mason fetches
the right binary for each into `~/.local/share/nvim/mason/bin`.

**Putting it together** — opening a `.tsx` file: treesitter colours it, `vtsls`
(started by nvim, installed by Mason) reports type errors, `prettier` formats on
save. Three separate programs, one editor.

---

## 4. Startup order

```
1. lua/config/options.lua   ← your settings, loaded FIRST
2. lazy.nvim starts, reads the plugin list
3. plugin modules are sourced   ← extras read your vim.g.* variables HERE
4. UI appears — nvim is usable
5. "VeryLazy" fires, milliseconds later — deferred, non-essential setup
```

Two consequences worth internalising:

**Step 1 precedes step 3.** This is why `vim.g.lazyvim_python_lsp = "basedpyright"`
must live in `options.lua`. The python extra reads that variable while loading at
step 3; setting it later has no effect. The failure mode is silent — Python keeps
linting and formatting but loses type checking, with no error anywhere.

**Step 5 is deferred on purpose.** LazyVim blanks `clipboard` at startup and restores
it at VeryLazy, because clipboard tools can be slow to spawn. Anything that inspects
the editor before step 5 — including `:checkhealth` invoked from a `-c` flag — will
report clipboard and UI overrides as "missing" when they are merely not yet applied.
Do not chase those.

**Lazy loading** runs throughout: most plugins never load at startup. `render-markdown`
has `ft = "markdown"` and loads on the first `.md` file; `claudecode.nvim` loads when
`<leader>a` is pressed. Roughly two-thirds of the 47 plugins are idle at any moment,
which is what keeps startup fast.

---

## 5. How overrides merge — and the one trap

When two specs name the same plugin, lazy.nvim **deep-merges** their `opts` tables.
`lua/plugins/markdown.lua` supplies only the handful of options that differ; LazyVim's
`lang.markdown` extra supplies the rest, and both apply with yours winning conflicts.
You never restate what you are happy with.

**The trap:** `config = function() ... end` does *not* merge. It **replaces** the
plugin's entire setup call, so the distro's own wiring for that plugin silently
disappears. This is the single most common way configs like this break.

> Override with `opts` and `keys`. Never write `config = function()` in
> `lua/plugins/` unless you intend to take over that plugin completely.

---

## 6. Where to change what

| Goal | Where |
|---|---|
| Add a language | `:LazyExtras` → `x` → restart. Commit `lazyvim.json`. |
| Change a plugin's behaviour | New file in `lua/plugins/`, returning a spec with `opts` |
| Add a keybinding | `lua/config/keymaps.lua` |
| Change an editor setting | `lua/config/options.lua` |
| Run something on a file event | `lua/config/autocmds.lua` |
| Update plugins | `:Lazy` → `U`. Commit the changed `lazy-lock.json`. |

---

## 7. Diagnosing a breakage

Ask the three questions in order — each isolates one engine:

1. `:Lazy` — did the plugin load at all? (Also shows per-plugin load times.)
2. `:LspInfo` — did a language server attach to this buffer?
3. `:Mason` — is the underlying tool actually installed?

Then `:LazyHealth` for a broad sweep. Read `ERROR` lines; most `WARNING`s are optional
features. Known-benign errors on this machine: `luarocks` missing (only needed by
plugins that require it), and the image/mermaid renderers, which need a terminal
supporting the kitty graphics protocol.

**Known gotcha — nvm.** JS/TS servers are installed under `~/.local/share/nvim`, but
run with whatever `node` is on `PATH`. After switching Node major versions, TypeScript
support may go quiet; fix with `:MasonInstall vtsls`.

---

## 8. What's installed

`:Lazy` is authoritative — the list below is orientation and will drift.

- **Daily drivers:** `snacks.nvim` (picker, explorer, terminal, lazygit, dashboard —
  one plugin doing ~10 jobs), `blink.cmp` (completion), `which-key.nvim` (the Space
  menu), `flash.nvim` (2-keystroke jumps), `gitsigns.nvim`, `trouble.nvim`
- **Language intelligence:** `nvim-lspconfig`, `mason.nvim`, `nvim-treesitter`,
  `conform.nvim` (format), `nvim-lint`, `SchemaStore.nvim`, `lazydev.nvim`
- **Per-language:** `clangd_extensions`, `cmake-tools` (C++); `nvim-dap-python`,
  `neotest-python`, `venv-selector` (Python); `nvim-ts-autotag` (JSX);
  `render-markdown` + `markdown-preview` (in-buffer and browser previews — two
  different tools, keep whichever you prefer)
- **Debug/test:** `nvim-dap` (+ `-ui`, `-virtual-text`), `neotest`. Installed but
  needing a per-project launch config, same as VSCode's `launch.json`.
- **Appearance:** `lualine`, `bufferline`, `noice`, `tokyonight` (active), `catppuccin`
- **Editing helpers:** `mini.ai`, `mini.pairs`, `ts-comments`, `todo-comments`,
  `grug-far` (project-wide replace), `persistence` (reopen last session)
- **AI:** `claudecode.nvim` — the only hand-added plugin; `<leader>ac` opens the
  claude CLI in a split that can see the current buffer and selection
