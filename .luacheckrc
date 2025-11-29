-- Luacheck configuration for nohands.nvim
-- See: https://github.com/mpeterv/luacheck

std = "luajit"  -- Neovim embeds LuaJIT

-- Treat these as read-only globals provided by Neovim/runtime
read_globals = {
  "vim",
}

-- Files to check (default is current dir); exclude vendor or build dirs if added later
files = {
  "lua/nohands/**/*.lua",
  "plugin/**/*.lua",
}

-- Ignore generated types stub file returning {} only
ignore = {
  -- pattern-based ignores (empty for now)
}

-- Allow unused arguments with leading underscore
unused_args = false
allow_defined = true
max_line_length = 200

-- Enable color output if run in terminal
color = true

-- Global warnings you want to silence can be added here, e.g.
-- globals = { } -- (not used; prefer read_globals)

-- Module-specific overrides example:
-- modules = {
--   ["lua/nohands/api.lua"] = { globals = { "vim", "curl" } }
-- }
