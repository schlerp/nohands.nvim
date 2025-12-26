local M = {}

function M.check()
  vim.health.start "nohands.nvim"

  -- Check curl
  if vim.fn.executable "curl" == 1 then
    vim.health.ok "curl is installed"
  else
    vim.health.error "curl is not installed"
  end

  -- Check git (for diffs)
  if vim.fn.executable "git" == 1 then
    vim.health.ok "git is installed"
  else
    vim.health.warn "git is not installed (diff features will not work)"
  end

  -- Check API key
  local config = require("nohands.config").get()
  local key_env = config.openrouter.api_key_env
  if vim.env[key_env] then
    vim.health.ok(string.format("API key found in environment variable $%s", key_env))
  else
    vim.health.error(string.format("API key not found in environment variable $%s", key_env))
  end

  -- Check dependencies (optional but good)
  local has_plenary, _ = pcall(require, "plenary")
  if has_plenary then
    vim.health.ok "plenary.nvim is installed"
  else
    vim.health.error "plenary.nvim is not installed"
  end
end

return M
