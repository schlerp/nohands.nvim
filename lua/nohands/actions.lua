local config = require "nohands.config"
local prompts = require "nohands.prompts"
local content = require "nohands.content"
local api = require "nohands.api"
local sessions = require "nohands.sessions"

local M = {}

local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

local indicator_state = { timer = nil, frame = 1 }

local function stop_indicator()
  if indicator_state.timer then
    indicator_state.timer:stop()
    indicator_state.timer:close()
    indicator_state.timer = nil
  end
  pcall(vim.api.nvim_echo, {}, false, {})
end

local function start_indicator()
  local cfg = config.get()
  if not (cfg.indicator and cfg.indicator.enabled) then
    return
  end
  stop_indicator()
  indicator_state.frame = 1
  local timer = vim.loop.new_timer()
  indicator_state.timer = timer
  timer:start(
    0,
    120,
    vim.schedule_wrap(function()
      if not indicator_state.timer then
        return
      end
      local frame = spinner_frames[indicator_state.frame]
      indicator_state.frame = indicator_state.frame % #spinner_frames + 1
      pcall(vim.api.nvim_echo, { { frame .. " nohands: querying model...", "ModeMsg" } }, false, {})
    end)
  )
end

local function write_output(method, text, incremental)
  if method == "replace" then
    local mode = vim.fn.mode()
    if mode:match "v" then
      vim.cmd [[normal! gv]]
      local _, sline, _, _ = unpack(vim.fn.getpos "'<")
      local _, eline, _, _ = unpack(vim.fn.getpos "'>")
      sline = sline - 1
      eline = eline - 1
      local new_lines = vim.split(text, "\n")
      vim.api.nvim_buf_set_lines(0, sline, eline + 1, false, new_lines)
      return
    end
    local line = vim.api.nvim_win_get_cursor(0)[1] - 1
    local new_lines = vim.split(text, "\n")
    vim.api.nvim_buf_set_lines(0, line, line + 1, false, new_lines)
  elseif method == "append" then
    local line = vim.api.nvim_win_get_cursor(0)[1]
    local new_lines = vim.split(text, "\n")
    vim.api.nvim_buf_set_lines(0, line, line, false, new_lines)
  elseif method == "float" then
    if incremental and incremental.buf then
      local lines = vim.split(text, "\n")
      vim.api.nvim_buf_set_lines(incremental.buf, 0, -1, false, lines)
      return incremental
    end
    local buf = vim.api.nvim_create_buf(false, true)
    local lines = vim.split(text, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    local width = math.min(math.max(60, math.floor(vim.o.columns * 0.6)), vim.o.columns - 4)
    local height = math.min(#lines, math.floor(vim.o.lines * 0.7))
    local row = math.floor((vim.o.lines - height) / 2 - 1)
    local col = math.floor((vim.o.columns - width) / 2)
    vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      row = row,
      col = col,
      width = width,
      height = height,
      style = "minimal",
      border = "rounded",
    })
    vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
    return { buf = buf }
  else
    local direction = config.get().output.split_direction
    if direction == "right" then
      vim.cmd "vsplit"
    else
      vim.cmd "split"
    end
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.split(text, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
  end
end

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
  local messages, perr = prompts.render(opts.prompt or "explain", cobj.text, { meta = cobj.meta })
  if not messages then
    vim.notify("nohands: " .. perr, vim.log.levels.ERROR)
    return
  end
  -- add content messages to session history
  for _, m in ipairs(messages) do
    table.insert(session.messages, m)
  end
  vim.notify(
    "nohands: querying model" .. (opts.stream and " (streaming)..." or "..."),
    vim.log.levels.INFO
  )
  start_indicator()

  local method = opts.output or cfg.output.method
  if opts.stream then
    local acc = {}
    local acc_len = 0
    local float_state = nil
    local last_flush = vim.loop.now()
    local flush_interval = (cfg.stream and cfg.stream.flush_interval_ms) or 120
    local function current_text()
      return table.concat(acc)
    end
    api.chat_stream(opts.model or cfg.model, session.messages, opts, function(chunk)
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
        float_state = write_output(method, current_text(), float_state)
        last_flush = now
      end
    end, function(full)
      stop_indicator()
      table.insert(session.messages, { role = "assistant", content = full })
      write_output(method, full, float_state)
    end, function(err)
      stop_indicator()
      vim.notify("nohands stream error: " .. err, vim.log.levels.ERROR)
    end)
  else
    local out, err = api.chat(opts.model or cfg.model, session.messages, opts)
    stop_indicator()
    if not out then
      vim.notify("nohands error: " .. err, vim.log.levels.ERROR)
      return
    end
    table.insert(session.messages, { role = "assistant", content = out })
    write_output(method, out)
  end
end

return M
