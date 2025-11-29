local M = {}

local function report(ok, msg)
  if vim.health and vim.health.start then
    if ok then
      vim.health.ok(msg)
    else
      vim.health.warn(msg)
    end
  else
    vim.notify(msg, ok and vim.log.levels.INFO or vim.log.levels.WARN)
  end
end

function M.check()
  if vim.health and vim.health.start then
    vim.health.start "nohands.nvim"
  end
  local has_plenary = pcall(require, "plenary.curl")
  report(has_plenary, has_plenary and "plenary.curl available" or "plenary.curl missing")
  local cfg = require("nohands.config").get()
  local key = vim.env[cfg.openrouter.api_key_env]
  report(
    key and #key > 0,
    key and ("API key in $" .. cfg.openrouter.api_key_env)
      or ("Missing $" .. cfg.openrouter.api_key_env)
  )
  local curl_ok = vim.fn.executable "curl" == 1
  report(curl_ok, curl_ok and "curl executable present" or "curl executable not found")
end

return M
