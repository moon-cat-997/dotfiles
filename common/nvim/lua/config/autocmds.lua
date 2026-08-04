-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- C/C++ indents 4 spaces, not LazyVim's global default of 2.
-- These filetypes use `cindent`, which RECALCULATES a new line's indent from the
-- enclosing braces times `shiftwidth` (rather than copying the line above). With
-- shiftwidth=2 against 4-space sources, every fresh line lands 2 columns short.
-- A repo's .editorconfig still wins over this, since editorconfig applies later.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("cpp_indent_4", { clear = true }),
  pattern = { "c", "cpp", "objc", "objcpp", "cuda" },
  callback = function()
    vim.bo.expandtab = true
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
    vim.bo.softtabstop = 4
  end,
})
