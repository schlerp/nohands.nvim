local config = require "nohands.config"
local prompts = require "nohands.prompts"
local content = require "nohands.content"
local api = require "nohands.api"
local sessions = require "nohands.sessions"
local output = require "nohands.output"

local M = {}

---@param opts NoHandsRunOptions|nil
function M.run(opts)
  opts = opts or {}
  local cfg = config.get()
  local source_key = opts.source or "buffer"
  local cobj = (
    source_key == "surrounding" and content.surrounding(opts.before, opts.after)
    or (source_key == "buffer" and content.buffer(opts.bufnr))
    or content.get(source_key, opts)
  )
  local session = sessions.get(opts.session)
  local prompt_name = opts.prompt or "explain"
  local prompt_def = prompts.get(prompt_name)
  local messages, perr = prompts.render(prompt_name, cobj.text, { meta = cobj.meta })
  if not messages then
    vim.notify("nohands: " .. perr, vim.log.levels.ERROR)
    return
  end
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
    local acc = {}
    local acc_len = 0
    local float_state = nil
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
        float_state = output.write(method, current_text(), float_state)
        last_flush = now
      end
    end, function(full)
      table.insert(session.messages, { role = "assistant", content = full })
      output.write(method, full, float_state)
    end, function(err)
      vim.notify("nohands stream error: " .. err, vim.log.levels.ERROR)
    end)
  else
    local out, err = api.chat(effective_model, session.messages, user_opts)
    if not out then
      vim.notify("nohands error: " .. err, vim.log.levels.ERROR)
      return
    end
    table.insert(session.messages, { role = "assistant", content = out })
    output.write(method, out)
  end
end

return M
