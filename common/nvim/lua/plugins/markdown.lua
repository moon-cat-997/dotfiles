-- Markdown preview, carried over from the pre-LazyVim config that lived at
-- ~/.config/nvim/init.lua (kept at ~/.config/nvim.bak/init.lua).
--
-- LazyVim's `lang.markdown` extra already installs render-markdown.nvim, so this
-- file only *overrides* its options rather than redeclaring the plugin. lazy.nvim
-- deep-merges `opts` tables, and `keys` entries are appended — so LazyVim's own
-- markdown wiring (treesitter parsers, marksman LSP, formatting) stays intact.
--
-- Deliberately no `config = function()` here: defining one would replace LazyVim's
-- setup call instead of extending it, which is the usual way these overrides break.

return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      -- Keep rendering while editing in normal mode, not just when idle.
      render_modes = { "n", "c", "t" },
      heading = {
        sign = true,
        icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
      },
      code = { style = "full", width = "block", border = "thin" },
    },
    keys = {
      {
        "<leader>m",
        "<cmd>RenderMarkdown toggle<cr>",
        desc = "Markdown: toggle preview (raw <-> rendered)",
      },
    },
  },
}
