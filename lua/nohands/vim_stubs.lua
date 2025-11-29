---@meta
-- Minimal type stubs for Neovim Lua API used in this plugin.
-- LuaLS only; runtime not loaded.

---@class VimApi
local VimApi = {} -- luacheck: ignore

function VimApi.nvim_get_current_buf() end
function VimApi.nvim_buf_get_lines(bufnr, start, end_, strict) end
function VimApi.nvim_buf_get_name(bufnr) end
function VimApi.nvim_win_get_cursor(win) end
function VimApi.nvim_create_buf(listed, scratch) end
function VimApi.nvim_buf_set_lines(buf, start, end_, strict, replacement) end
function VimApi.nvim_buf_set_option(buf, name, value) end
function VimApi.nvim_open_win(buffer, enter, config) end
function VimApi.nvim_create_user_command(name, command, opts) end

---@class VimGlobal
---@field loaded_nohands boolean

---@class Vim
---@field api VimApi
---@field fn table
---@field env table<string,string>
---@field g VimGlobal
---@field o table
---@field log { levels: { ERROR: integer, WARN: integer, INFO: integer } }
---@field json { encode: fun(tbl:table):string, decode: fun(str:string):table }
local vim = vim -- luacheck: ignore

return {}
