local config = require "nohands.config"
local prompts = require "nohands.prompts"
local api = require "nohands.api"
local actions = require "nohands.actions"

local M = {}

local function snacks_available()
  return pcall(require, "snacks")
end

---@return nil
function M.open()
  if not config.get().picker.use_snacks or not snacks_available() then
    vim.notify("nohands: Snacks picker disabled or not found", vim.log.levels.WARN)
    return
  end
  local snacks = require "snacks"
  local cfg = config.get()
  local function select_prompt(cb)
    local prompt_items = prompts.list()
    local prompt_choices = {}
    for _, p in ipairs(prompt_items) do
      prompt_choices[#prompt_choices + 1] = { text = p.name, value = p.name }
    end
    snacks.picker.prompt {
      title = "nohands: select prompt",
      items = prompt_choices,
      on_submit = function(sel)
        cb(sel.value)
      end,
    }
  end
  local function select_source(prompt_name, session_name)
    local sources = {
      { text = "buffer", value = "buffer" },
      { text = "selection", value = "selection" },
      { text = "surrounding (10/10)", value = "surrounding", before = 10, after = 10 },
      { text = "diff (git)", value = "diff" },
    }
    snacks.picker.prompt {
      title = "nohands: select source",
      items = sources,
      on_submit = function(src_sel)
        local source = src_sel.value
        local before = src_sel.before
        local after = src_sel.after
        local models = api.list_models()
        if #models == 0 then
          models = { cfg.model }
        end
        local items = {}
        for _, m in ipairs(models) do
          items[#items + 1] = { text = m, value = m }
        end
        snacks.picker.prompt {
          title = "nohands: select model",
          items = items,
          on_submit = function(model_sel)
            actions.run {
              session = session_name,
              prompt = prompt_name,
              source = source,
              before = before,
              after = after,
              model = model_sel.value,
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
    snacks.picker.prompt {
      title = "nohands: select session",
      items = session_items,
      on_submit = function(sel)
        start_flow(sel.value)
      end,
    }
  else
    start_flow(nil)
  end
end

return M
