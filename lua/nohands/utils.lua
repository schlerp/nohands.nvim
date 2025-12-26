---@class NoHandsUtils
local M = {}

local config = require "nohands.config"

---Check if the current mode is a visual mode (v, V, or CTRL-V).
---@return boolean
function M.is_visual_mode()
  local mode = vim.fn.mode()
  return mode == "v" or mode == "V" or mode == "\22"
end

---Join a list of lines into a single string.
---@param lines string[]
---@return string
function M.join_lines(lines)
  return table.concat(lines, "\n")
end

---Get standard API headers for requests.
---@return table<string, string>
function M.get_api_headers()
  local opts = config.get().openrouter
  local key = vim.env[opts.api_key_env]
  local h = {
    Authorization = "Bearer " .. (key or ""),
    ["Content-Type"] = "application/json",
  }
  if opts.referer then
    h["HTTP-Referer"] = opts.referer
  end
  if opts.title then
    h["X-Title"] = opts.title
  end
  return h
end

---Get CLI arguments for curl headers based on configuration.
---@return string[]
function M.get_curl_header_args()
  local headers = M.get_api_headers()
  local args = {}
  for k, v in pairs(headers) do
    table.insert(args, "-H")
    table.insert(args, string.format("%s: %s", k, v))
  end
  return args
end

return M
