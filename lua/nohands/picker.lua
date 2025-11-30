local config = require "nohands.config"
local prompts = require "nohands.prompts"
local api = require "nohands.api"
local actions = require "nohands.actions"

local M = {}

local function snacks_available()
  return pcall(require, "snacks")
end

-- Wrapper to create a simple value picker (non-file) using Snacks.
-- Falls back to the test stub (picker.prompt) in CI.
---@param opts {title:string, items:table[], cb:fun(value:string)}
local function picker_select(opts)
  local snacks = require "snacks"
  local picker = snacks.picker
  local items = opts.items or {}

  -- Normalize items to {text=..., value=...}
  local norm = {}
  for _, it in ipairs(items) do
    local txt = it.text or it.value
    norm[#norm + 1] = { text = txt, value = it.value or it.text }
  end

  -- Use Snacks generic picker with an in-memory finder for fuzzy matching.
  if type(picker.pick) == "function" then
    picker.pick {
      title = opts.title,
      items = norm,
      preview = false,
      layout = { preset = "select" },
      auto_confirm = #norm == 1,
      format_item = function(item)
        if type(item) == "string" then
          return item
        end
        return item.text or tostring(item.value)
      end,
      confirm = function(p, item)
        if item then
          opts.cb(item.value)
        end
        if p and p.close then
          pcall(function()
            p:close()
          end)
        elseif snacks.picker and snacks.picker.close then
          pcall(function()
            snacks.picker.close()
          end)
        end
      end,
    }
    return
  end

  -- Fallback: test stub defined in tests/minimal_init.lua exposes picker.prompt
  if picker.prompt then
    picker.prompt {
      title = opts.title,
      items = norm,
      on_submit = function(sel)
        if sel then
          opts.cb(sel.value)
        end
      end,
    }
  end
end

---@return nil
function M.open()
  if not config.get().picker.use_snacks or not snacks_available() then
    vim.notify("nohands: Snacks picker disabled or not found", vim.log.levels.WARN)
    return
  end
  local cfg = config.get()
  local orig_buf = vim.api.nvim_get_current_buf()

  -- 1. Prompt selection
  local function select_prompt(cb)
    local prompt_items = prompts.list()
    local prompt_choices = {}
    for _, p in ipairs(prompt_items) do
      prompt_choices[#prompt_choices + 1] = { text = p.name, value = p.name }
    end
    picker_select {
      title = "nohands: select prompt",
      items = prompt_choices,
      cb = cb,
    }
  end

  -- 2. Source selection -> Model selection -> Execute action
  local function select_source(prompt_name, session_name)
    local sources = {
      { text = "buffer", value = "buffer" },
      { text = "selection", value = "selection" },
      { text = "surrounding (10/10)", value = "surrounding", before = 10, after = 10 },
      { text = "diff (git)", value = "diff" },
    }
    picker_select {
      title = "nohands: select source",
      items = sources,
      cb = function(src_value)
        local source
        local before
        local after
        for _, s in ipairs(sources) do
          if (s.value or s.text) == src_value then
            source = s.value or s.text
            before = s.before
            after = s.after
            break
          end
        end
        local models = api.list_models()
        if #models == 0 then
          models = { cfg.model }
        end
        local model_items = {}
        for _, m in ipairs(models) do
          model_items[#model_items + 1] = { text = m, value = m }
        end
        picker_select {
          title = "nohands: select model",
          items = model_items,
          cb = function(model_value)
            -- Restore original buffer before capturing content
            if vim.api.nvim_buf_is_valid(orig_buf) then
              vim.api.nvim_set_current_buf(orig_buf)
            end
            actions.run {
              session = session_name,
              prompt = prompt_name,
              source = source,
              before = before,
              after = after,
              model = model_value,
              bufnr = orig_buf,
            }
          end,
        }
      end,
    }
  end

  local function start_flow(session_name)
    select_prompt(function(prompt_name)
      select_source(prompt_name, session_name)
    end)
  end

  -- Optional initial session selection
  if cfg.picker.session_first then
    local names = {}
    for k, _ in pairs(require("nohands.sessions").store) do
      names[#names + 1] = k
    end
    if #names == 0 then
      names = { "default" }
    end
    local session_items = {}
    for _, n in ipairs(names) do
      session_items[#session_items + 1] = { text = n, value = n }
    end
    picker_select {
      title = "nohands: select session",
      items = session_items,
      cb = function(session_value)
        start_flow(session_value)
      end,
    }
  else
    start_flow(nil)
  end
end

return M
