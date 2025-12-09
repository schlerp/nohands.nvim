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

  -- default keymaps (configurable via `keys` table)
  local keys = M.config.keys or {}
  local map = vim.keymap.set
  local base_opts = { noremap = true }

  if keys.nohands ~= false then
    map("n", keys.nohands or "<leader>nn", "<cmd>NoHands<CR>", base_opts)
  end
  if keys.run ~= false then
    local run_key = keys.run or "<leader>nr"
    map("n", run_key, function()
      actions.run { prompt = "explain", stateless = true }
    end, base_opts)
    map("v", run_key, function()
      actions.run { prompt = "explain", source = "selection", stateless = true }
    end, base_opts)
  end
  if keys.stream ~= false then
    local stream_key = keys.stream or "<leader>ns"
    map("n", stream_key, function()
      actions.run {
        prompt = "explain",
        stream = true,
        output = "float",
        stateless = true,
      }
    end, base_opts)
    map("v", stream_key, function()
      actions.run {
        prompt = "explain",
        stream = true,
        output = "float",
        source = "selection",
        stateless = true,
      }
    end, base_opts)
  end
  if keys.refactor ~= false then
    local refactor_key = keys.refactor or "<leader>ni"
    map("n", refactor_key, function()
      actions.run { prompt = "refactor", stateless = true }
    end, base_opts)
    map("v", refactor_key, function()
      actions.run { prompt = "refactor", source = "selection", stateless = true }
    end, base_opts)
  end
  if keys.palette ~= false then
    map("n", keys.palette or "<leader>np", "<cmd>NoHandsPalette<CR>", base_opts)
  end
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
    local prompt_name = cmd_opts.args ~= "" and cmd_opts.args or "explain"
    local mode = vim.fn.mode()
    local source
    if mode:match "v" then
      source = "selection"
    end
    local prompt_def = prompts.get(prompt_name)
    local cfg_now = config.get()
    local model = (prompt_def and prompt_def.model) or cfg_now.model
    local status = string.format("nohands: requesting %s (%s)...", model, prompt_name)
    vim.api.nvim_echo({ { status, "ModeMsg" } }, false, {})
    vim.cmd "redraw"
    vim.schedule(function()
      actions.run { prompt = prompt_name, source = source, output = "float" }
    end)
  end, { nargs = "?" })
  vim.api.nvim_create_user_command("NoHandsStream", function(cmd_opts)
    local prompt_name = cmd_opts.args ~= "" and cmd_opts.args or "explain"
    local mode = vim.fn.mode()
    local source
    if mode:match "v" then
      source = "selection"
    end
    local prompt_def = prompts.get(prompt_name)
    local cfg_now = config.get()
    local model = (prompt_def and prompt_def.model) or cfg_now.model
    local status = string.format("nohands: streaming %s (%s)...", model, prompt_name)
    vim.api.nvim_echo({ { status, "ModeMsg" } }, false, {})
    vim.cmd "redraw"
    vim.schedule(function()
      actions.run {
        prompt = prompt_name,
        stream = true,
        output = "split",
        source = source,
      }
    end)
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
