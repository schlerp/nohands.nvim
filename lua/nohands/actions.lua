local config = require "nohands.config"
local prompts = require "nohands.prompts"
local content = require "nohands.content"
local api = require "nohands.api"
local sessions = require "nohands.sessions"
local output = require "nohands.output"

local M = {}

local function latest_user_text(messages)
  for i = #messages, 1, -1 do
    local m = messages[i]
    if m.role == "user" and type(m.content) == "string" then
      return m.content
    end
  end
  return nil
end

local function format_header(prompt_name, request_text)
  local lines = {}

  lines[#lines + 1] = ("### Prompt: %s"):format(prompt_name)
  if request_text and request_text ~= "" then
    lines[#lines + 1] = ""
    lines[#lines + 1] = request_text
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "### Response"
  lines[#lines + 1] = ""

  return table.concat(lines, "\n")
end

local function format_full(prompt_name, request_text, reply_text)
  local header = format_header(prompt_name, request_text)
  if not reply_text or reply_text == "" then
    return header
  end
  return header .. reply_text
end

local function notify_usage(usage, model)
  local cfg = config.get()
  if not (cfg.usage and cfg.usage.notify) then
    return
  end
  if not usage or type(usage) ~= "table" then
    return
  end

  local prompt = usage.prompt_tokens or usage.input_tokens or 0
  local completion = usage.completion_tokens or usage.output_tokens or 0
  local total = usage.total_tokens or (prompt + completion)

  local label = model or "model"
  local msg = string.format(
    "nohands: usage (%s)\n  prompt     %d\n  completion %d\n  total      %d",
    label,
    prompt,
    completion,
    total
  )

  vim.notify(msg, vim.log.levels.INFO)
end

---@param opts NoHandsRunOptions|nil
function M.run(opts)
  opts = opts or {}
  local cfg = config.get()
  local source_key = opts.source
  if not source_key then
    local mode = vim.fn.mode()
    if mode:match "v" then
      source_key = "selection"
    else
      source_key = "buffer"
    end
  end
  local cobj = (
    source_key == "surrounding" and content.surrounding(opts.before, opts.after)
    or (source_key == "buffer" and content.buffer(opts.bufnr))
    or content.get(source_key, opts)
  )

  local stateless = opts.stateless
  local session
  if stateless then
    session = { id = opts.session or "stateless", messages = {} }
  else
    session = sessions.get(opts.session)
  end
  local prompt_name = opts.prompt or "explain"
  local prompt_def = prompts.get(prompt_name)
  local messages, perr = prompts.render(prompt_name, cobj.text, { meta = cobj.meta })
  if not messages then
    vim.notify("nohands: " .. perr, vim.log.levels.ERROR)
    return
  end
  local request_text = latest_user_text(messages)
  -- add content messages to session history
  for _, m in ipairs(messages) do
    table.insert(session.messages, m)
  end
  local method = opts.output or cfg.output.method
  if method == "replace" or method == "append" then
    method = "split"
  end

  local effective_model = opts.model or (prompt_def and prompt_def.model) or cfg.model
  local effective_temp = opts.temperature
    or (prompt_def and prompt_def.temperature)
    or cfg.temperature
  local effective_max = opts.max_tokens or (prompt_def and prompt_def.max_tokens) or cfg.max_tokens

  local user_opts = {
    temperature = effective_temp,
    max_tokens = effective_max,
  }

  if opts.stream then
    local status = string.format("nohands: streaming %s (%s)...", effective_model, prompt_name)
    vim.api.nvim_echo({ { status, "ModeMsg" } }, false, {})
    vim.cmd "redraw"

    local header = format_header(prompt_name, request_text)
    local acc = {}
    local acc_len = 0
    local state = nil
    local last_flush = vim.loop.now()
    local flush_interval = (cfg.stream and cfg.stream.flush_interval_ms) or 120
    local function current_text()
      return table.concat(acc)
    end
    api.chat_stream(effective_model, session.messages, user_opts, function(chunk)
      acc[#acc + 1] = chunk
      acc_len = acc_len + #chunk
      local maxc = cfg.stream and cfg.stream.max_accumulate or 16000
      if acc_len > maxc then
        local joined = current_text()
        local trimmed = joined:sub(#joined - maxc + 1)
        acc = { trimmed }
        acc_len = #trimmed
      end
      local now = vim.loop.now()
      if (now - last_flush) >= flush_interval then
        state = output.write(method, header .. current_text(), state)
        last_flush = now
      end
    end, function(full)
      table.insert(session.messages, { role = "assistant", content = full })
      output.write(method, header .. full, state)
    end, function(err)
      vim.notify("nohands stream error: " .. err, vim.log.levels.ERROR)
    end)
  else
    local status = string.format("nohands: requesting %s (%s)...", effective_model, prompt_name)
    vim.api.nvim_echo({ { status, "ModeMsg" } }, false, {})
    vim.cmd "redraw"
    api.chat_async(effective_model, session.messages, user_opts, function(out, usage)
      table.insert(session.messages, { role = "assistant", content = out })
      local display = format_full(prompt_name, request_text, out)
      output.write(method, display)
      notify_usage(usage, effective_model)
    end, function(err)
      vim.notify("nohands error: " .. err, vim.log.levels.ERROR)
    end)
  end
end

return M
