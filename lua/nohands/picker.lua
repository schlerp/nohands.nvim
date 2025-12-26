local config = require "nohands.config"
local prompts = require "nohands.prompts"
local api = require "nohands.api"
local actions = require "nohands.actions"

local M = {}

-- Wrapper to create a simple value picker (non-file).
-- Uses vim.ui.select so Snacks (or any other plugin) can override it.
---@param opts {title:string, items:table[], cb:fun(value:string)}
local function picker_select(opts)
  local items = opts.items or {}

  -- Normalize items to { text = label, value = actual }
  local norm = {}
  for _, it in ipairs(items) do
    local label = it.text or it.value or tostring(it)
    local value = it.value or it.text or it
    norm[#norm + 1] = { text = label, value = value }
  end

  if not (vim.ui and vim.ui.select) then
    vim.notify("nohands: vim.ui.select is not available", vim.log.levels.ERROR)
    return
  end

  vim.ui.select(norm, {
    prompt = opts.title,
    format_item = function(item)
      return item.text or tostring(item.value)
    end,
  }, function(choice)
    if not choice then
      return
    end
    opts.cb(choice.value or choice.text or choice)
  end)
end

local function build_palette_items()
  local items = {}
  local prompt_items = prompts.list()
  for _, p in ipairs(prompt_items) do
    local label
    if type(p.tags) == "table" and #p.tags > 0 then
      local tag_str = table.concat(p.tags, ",")
      label = string.format("%s [%s] · buffer", p.name, tag_str)
    else
      label = string.format("%s · buffer", p.name)
    end
    items[#items + 1] = { text = label, value = p.name .. "::buffer" }
  end
  return items
end

---@return nil
function M.open()
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
      { text = "LSP symbol", value = "lsp_symbol" },
      { text = "diagnostic", value = "diagnostic" },
      { text = "quickfix list", value = "quickfix" },
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

        vim.notify(
          "Fetching models...",
          vim.log.levels.INFO,
          { title = "nohands.nvim", id = "nohands_models" }
        )
        api.list_models(function(models)
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
        end)
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

---@return nil
function M.palette()
  local cfg = config.get()
  local orig_buf = vim.api.nvim_get_current_buf()
  local items = build_palette_items()
  if #items == 0 then
    vim.notify("nohands: no prompts configured", vim.log.levels.WARN)
    return
  end
  picker_select {
    title = "nohands: palette",
    items = items,
    cb = function(encoded)
      local prompt_name, source = encoded:match "^(.-)::(.+)$"
      if not prompt_name or prompt_name == "" or not source or source == "" then
        return
      end
      if vim.api.nvim_buf_is_valid(orig_buf) then
        vim.api.nvim_set_current_buf(orig_buf)
      end
      actions.run {
        prompt = prompt_name,
        source = source,
        model = cfg.model,
        bufnr = orig_buf,
      }
    end,
  }
end

return M
