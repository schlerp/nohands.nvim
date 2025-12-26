local M = {}

function M.logfile()
  return vim.fn.stdpath "data" .. "/nohands.log"
end

function M.log(msg, level)
  local f = io.open(M.logfile(), "a")
  if not f then
    return
  end
  local timestamp = os.date "%Y-%m-%d %H:%M:%S"
  f:write(string.format("[%s] [%s] %s\n", timestamp, level or "INFO", msg))
  f:close()
end

function M.info(msg)
  M.log(msg, "INFO")
end

function M.error(msg)
  M.log(msg, "ERROR")
end

function M.warn(msg)
  M.log(msg, "WARN")
end

function M.view_logs()
  local log_path = M.logfile()
  if vim.fn.filereadable(log_path) == 0 then
    vim.notify("No logs found at " .. log_path, vim.log.levels.WARN, { title = "nohands.nvim" })
    return
  end

  vim.cmd "vsplit"
  vim.cmd("view " .. vim.fn.fnameescape(log_path))
  vim.bo.readonly = true
  vim.bo.modifiable = false
  vim.bo.buftype = "nofile"
  -- scroll to bottom
  vim.cmd "normal! G"
end

function M.view_history()
  -- Force save before reading to ensure latest in-memory sessions are on disk
  pcall(require("nohands.sessions").save)

  local history_path = require("nohands.sessions")._session_file()
  if vim.fn.filereadable(history_path) == 0 then
    vim.notify(
      "No history found at " .. history_path,
      vim.log.levels.WARN,
      { title = "nohands.nvim" }
    )
    return
  end

  local f = io.open(history_path, "r")
  if not f then
    return
  end
  local content = f:read "*a"
  f:close()

  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    -- Fallback to raw view if corrupt or not json
    vim.cmd "vsplit"
    vim.cmd("view " .. vim.fn.fnameescape(history_path))
    vim.bo.readonly = true
    vim.bo.modifiable = false
    vim.bo.buftype = "nofile"
    return
  end

  local lines = {}
  local ids = vim.tbl_keys(data)
  table.sort(ids)

  for _, id in ipairs(ids) do
    local session = data[id]
    table.insert(lines, "# Session: " .. id)
    table.insert(lines, string.rep("-", 40))
    table.insert(lines, "")
    for _, msg in ipairs(session.messages or {}) do
      local role = msg.role or "unknown"
      table.insert(lines, "### " .. role:upper())
      if msg.content then
        for _, l in ipairs(vim.split(msg.content, "\n")) do
          table.insert(lines, l)
        end
      end
      table.insert(lines, "")
    end
    table.insert(lines, string.rep("=", 40))
    table.insert(lines, "")
  end

  vim.cmd "vsplit"
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = "nofile"
  -- scroll to bottom
  vim.cmd "normal! G"
end

return M
