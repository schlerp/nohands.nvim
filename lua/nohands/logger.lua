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

return M
