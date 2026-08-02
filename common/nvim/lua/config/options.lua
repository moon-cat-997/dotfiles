-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Python language server. LazyVim's `lang.python` extra defaults to `pyright` and
-- enables ONLY the server named here — set it to something whose Mason package is
-- not installed and Python silently gets ruff (lint/format) with no type checking.
-- basedpyright is the maintained open-source fork of pyright, with stricter
-- inference and inlay hints. Must be set before the extra loads, hence options.lua.
vim.g.lazyvim_python_lsp = "basedpyright"

local opt = vim.opt

-- Carried over from the pre-LazyVim config (kept at ~/.config/nvim.bak/init.lua).
-- Everything else it set — relativenumber, shiftwidth=2, expandtab, smartindent,
-- termguicolors, signcolumn, mouse, clipboard=unnamedplus, ignorecase, smartcase —
-- is already a LazyVim default and is therefore not repeated here.
--
-- These two are kept explicit because together they produce a specific behaviour:
-- markdown markup (**, #, links) is hidden for readability, *except* on the line
-- the cursor is on, so the raw text is editable where you actually are.
opt.conceallevel = 2 -- hide markup characters that render-markdown draws over
opt.concealcursor = "" -- ...but never on the cursor line, in any mode
