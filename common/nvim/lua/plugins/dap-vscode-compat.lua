-- Make committed .vscode/launch.json debug configs work under nvim-dap.
--
-- The CodeLLDB VS Code extension registers its adapter as "lldb", so launch.json
-- files written for it say `"type": "lldb"`. LazyVim's clangd extra registers the
-- very same binary as "codelldb". Without an alias nvim-dap cannot resolve the
-- config and refuses to start the session.
--
-- IMPORTANT: this uses `opts`, not `config`. lazy.nvim chains `opts` functions
-- from every spec for a plugin, but a `config` function REPLACES the one from
-- earlier specs. Declaring `config` here silently disabled LazyVim's own dap
-- setup -- mason-nvim-dap registration, breakpoint sign icons, and launch.json
-- loading all live in it. Do not convert this back to `config`.

-- nvim-dap also ignores launch.json's `preLaunchTask` entirely (the key appears
-- nowhere in its source), so a config that builds its binary that way would
-- debug whatever stale artifact is left at that path. `<leader>dd` below stands
-- in for it: build first, then launch.

local function build_then_continue()
  local dap = require("dap")
  local root = vim.fs.root(0, { ".git" })
  local script = root and (root .. "/scripts/cxx-build.sh")
  local src = vim.api.nvim_buf_get_name(0)

  -- No project build script, or not a C++ buffer: behave like plain <leader>dc.
  if not script or vim.fn.executable(script) ~= 1 or not src:match("%.cpp$") then
    return dap.continue()
  end

  local out = vim.fn.system({ script, src, "/tmp/cf_debug_bin" })
  if vim.v.shell_error ~= 0 then
    vim.notify("Build failed:\n" .. out, vim.log.levels.ERROR)
    return
  end
  dap.continue()
end

return {
  "mfussenegger/nvim-dap",
  optional = true,
  -- stylua: ignore
  keys = {
    { "<leader>dd", build_then_continue, desc = "Build & Debug (C++)" },
  },
  opts = function()
    local dap = require("dap")

    -- `codelldb` is only on PATH once mason.nvim has loaded and prepended its
    -- bin directory. If the adapter starts before that, the server is never
    -- spawned and the session dies with a bare ECONNREFUSED. Prefer mason's
    -- absolute path so the adapter does not depend on load order at all.
    local mason_bin = vim.fn.stdpath("data") .. "/mason/bin/codelldb"
    local command = vim.fn.executable(mason_bin) == 1 and mason_bin or "codelldb"

    if not dap.adapters.lldb then
      -- A plain table, mirroring how LazyVim defines codelldb. Copied rather
      -- than aliased by reference because nvim-dap mutates the adapter in place
      -- (it rewrites "${port}" to a real port on first launch), and two config
      -- types sharing one table would tread on each other.
      dap.adapters.lldb = {
        type = "server",
        host = "localhost",
        port = "${port}",
        executable = {
          command = command,
          args = { "--port", "${port}" },
        },
      }
    end
  end,
}
