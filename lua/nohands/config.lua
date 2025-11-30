local M = {}

local defaults = {
  model = "openai/gpt-4o-mini",
  temperature = 0.2,
  max_tokens = 800,
  openrouter = {
    base_url = "https://openrouter.ai/api/v1",
    api_key_env = "OPENROUTER_API_KEY",
    referer = nil,
    title = "nohands.nvim",
  },
  prompts = {},
  output = {
    method = "split",
    split_direction = "below",
  },
  picker = {
    use_snacks = true,
    session_first = false, -- if true picker starts with session selection
  },
  stream = {
    max_accumulate = 16000, -- max chars kept before flush
    flush_interval_ms = 120, -- minimum interval between UI updates (stream)
  },
  diff = {
    write_before = true, -- write buffer before diff to compare with disk
    unified = 3, -- number of context lines
    async = false, -- if true use async system call for diff
  },
  models = {
    cache_ttl = 300, -- seconds to cache list_models results
  },
  retry = {
    attempts = 2, -- number of retry attempts for chat
    backoff_ms = 200, -- base backoff milliseconds
  },
}

---@type NoHandsConfig
M.opts = vim.deepcopy(defaults)

---@param user_opts NoHandsConfig|nil
function M.setup(user_opts)
  if user_opts then
    M.opts = vim.tbl_deep_extend("force", defaults, user_opts)
  end
end

---@return NoHandsConfig
function M.get()
  return M.opts
end

return M
