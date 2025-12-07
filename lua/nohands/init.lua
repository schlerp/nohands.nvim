---@class NoHandsModule
---@field config NoHandsConfig
---@field setup fun(opts:NoHandsConfig|nil)
---@field run fun(opts:NoHandsRunOptions|nil)
---@field prompts table
---@field picker table
---@field actions table
---@field get_config fun():NoHandsConfig
---@field sessions table

local M = {}

local config = require "nohands.config"
local actions = require "nohands.actions"
local prompts = require "nohands.prompts"
local picker = require "nohands.picker"
local sessions = require "nohands.sessions"

M.config = config.get()

---@param opts NoHandsConfig|nil
function M.setup(opts)
  config.setup(opts)
  M.config = config.get()
  -- load persisted sessions if present
  pcall(sessions.load)
  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      pcall(sessions.save)
    end,
  })
  vim.api.nvim_create_user_command("NoHands", function(_)
    picker.open()
  end, {})
  vim.api.nvim_create_user_command("NoHandsPalette", function(_)
    picker.palette()
  end, {})
  vim.api.nvim_create_user_command("NoHandsRun", function(cmd_opts)
    actions.run { prompt = cmd_opts.args ~= "" and cmd_opts.args or "explain" }
  end, { nargs = "?" })
  vim.api.nvim_create_user_command("NoHandsStream", function(cmd_opts)
    actions.run {
      prompt = cmd_opts.args ~= "" and cmd_opts.args or "explain",
      stream = true,
      output = "float",
    }
  end, { nargs = "?" })
  vim.api.nvim_create_user_command("NoHandsSessions", function()
    local names = {}
    for k, _ in pairs(require("nohands.sessions").store) do
      table.insert(names, k)
    end
    if #names == 0 then
      table.insert(names, "default")
    end
    vim.ui.select(names, { prompt = "Select nohands session" }, function(choice)
      if choice then
        actions.run { session = choice, prompt = "explain", source = "buffer" }
      end
    end)
  end, {})
  vim.api.nvim_create_user_command("NoHandsApplyDiff", function()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    require("nohands.apply").apply_unified(table.concat(lines, "\n"))
  end, {})
  vim.api.nvim_create_user_command("NoHandsHealth", function()
    require("nohands.health").check()
  end, {})
end

M.run = actions.run
M.prompts = prompts
M.picker = picker
M.actions = actions
M.get_config = config.get
M.sessions = sessions

return M
