-- Luacheck configuration for nohands.nvim
-- See: https://github.com/mpeterv/luacheck

std = "luajit"  -- Neovim embeds LuaJIT

-- Treat these as read-only globals provided by Neovim/runtime
read_globals = {
  "vim",
}

-- Muting specific warnings (e.g. setting read-only fields of global 'vim')
-- Code 121: Setting a read-only global variable
-- Code 122: Setting a read-only field of a global variable
ignore = {
  "121", "122"
}

-- Files to check (default is current dir); exclude vendor or build dirs if added later
files = {
  "lua/nohands/**/*.lua",
  "plugin/**/*.lua",
  "tests/**/*.lua",
}

-- Use busted std for tests
stds = {
  ["tests"] = {
    globals = { "describe", "it", "before_each", "after_each", "setup", "teardown", "spy", "mock", "stub" }
  }
}

-- Ignore generated types stub file returning {} only
-- ignore = {
--   -- pattern-based ignores (empty for now)
-- }

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
