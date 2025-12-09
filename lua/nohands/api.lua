local config = require "nohands.config"
local curl = require "plenary.curl"
local M = {}

local _models_cache = { time = 0, list = {} }

local function headers()
  local opts = config.get().openrouter
  local key = vim.env[config.get().openrouter.api_key_env]
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

---@param model string|nil
---@param messages table
---@param user_opts table|nil
---@return string|nil content, string|nil error
function M.chat(model, messages, user_opts)
  local cfg = config.get()
  local body = {
    model = model or cfg.model,
    messages = messages,
    temperature = user_opts and user_opts.temperature or cfg.temperature,
    max_tokens = user_opts and user_opts.max_tokens or cfg.max_tokens,
  }
  local url = cfg.openrouter.base_url .. "/chat/completions"
  local attempts = (cfg.retry and cfg.retry.attempts) or 1
  local backoff = (cfg.retry and cfg.retry.backoff_ms) or 0
  local res
  local last_err
  for i = 1, attempts do
    local ok, result = pcall(curl.post, url, {
      headers = headers(),
      body = vim.json.encode(body),
    })
    if not ok then
      last_err = result
      res = nil
    else
      res = result
    end
    if res and res.status == 200 then
      break
    end
    if i < attempts and backoff > 0 then
      vim.wait(backoff * i)
    end
  end
  if not res or res.status ~= 200 then
    if last_err and (not res or not res.status) then
      return nil, "curl error: " .. tostring(last_err)
    end
    return nil, "HTTP " .. tostring(res and res.status or "nil") .. "\n" .. (res and res.body or "")
  end
  local ok, data = pcall(vim.json.decode, res.body)
  if not ok then
    return nil, "Failed to decode response"
  end
  local choice = data.choices and data.choices[1]
  if not choice or not choice.message or not choice.message.content then
    return nil, "No content in response"
  end
  return choice.message.content
end

---@param model string|nil
---@param messages table
---@param user_opts table|nil
---@param on_success fun(content:string, usage:table|nil)
---@param on_error fun(err:string)
function M.chat_async(model, messages, user_opts, on_success, on_error)
  local cfg = config.get()
  local body = {
    model = model or cfg.model,
    messages = messages,
    temperature = user_opts and user_opts.temperature or cfg.temperature,
    max_tokens = user_opts and user_opts.max_tokens or cfg.max_tokens,
  }
  local url = cfg.openrouter.base_url .. "/chat/completions"
  local cmd = {
    "curl",
    "-sS",
    "-X",
    "POST",
    url,
    "-H",
    "Authorization: Bearer " .. (vim.env[cfg.openrouter.api_key_env] or ""),
    "-H",
    "Content-Type: application/json",
  }
  if cfg.openrouter.referer then
    table.insert(cmd, "-H")
    table.insert(cmd, "HTTP-Referer: " .. cfg.openrouter.referer)
  end
  if cfg.openrouter.title then
    table.insert(cmd, "-H")
    table.insert(cmd, "X-Title: " .. cfg.openrouter.title)
  end
  table.insert(cmd, "-d")
  table.insert(cmd, vim.json.encode(body))
  vim.system(cmd, { text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        on_error("curl exit code " .. res.code)
        return
      end
      local ok, data = pcall(vim.json.decode, res.stdout)
      if not ok or type(data) ~= "table" then
        on_error "Failed to decode response"
        return
      end
      local choice = data.choices and data.choices[1]
      if not choice or not choice.message or not choice.message.content then
        on_error "No content in response"
        return
      end
      on_success(choice.message.content, data.usage)
    end)
  end)
end

-- Streaming using curl command (SSE events)
---@param model string|nil
---@param messages table
---@param user_opts table|nil
---@param on_chunk fun(text:string)
---@param on_finish fun(full:string, usage:table|nil)
---@param on_error fun(err:string)
function M.chat_stream(model, messages, user_opts, on_chunk, on_finish, on_error)
  local cfg = config.get()
  local body = {
    model = model or cfg.model,
    messages = messages,
    temperature = user_opts and user_opts.temperature or cfg.temperature,
    max_tokens = user_opts and user_opts.max_tokens or cfg.max_tokens,
    stream = true,
  }
  local url = cfg.openrouter.base_url .. "/chat/completions"
  local cmd = {
    "curl",
    "-s",
    "-N",
    "-X",
    "POST",
    url,
    "-H",
    "Authorization: Bearer " .. (vim.env[cfg.openrouter.api_key_env] or ""),
    "-H",
    "Content-Type: application/json",
  }
  if cfg.openrouter.referer then
    table.insert(cmd, "-H")
    table.insert(cmd, "HTTP-Referer: " .. cfg.openrouter.referer)
  end
  if cfg.openrouter.title then
    table.insert(cmd, "-H")
    table.insert(cmd, "X-Title: " .. cfg.openrouter.title)
  end
  table.insert(cmd, "-d")
  table.insert(cmd, vim.json.encode(body))
  local full = {}
  local usage
  vim.system(cmd, { text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        on_error("curl exit code " .. res.code)
        return
      end
      -- Parse SSE chunks line by line
      for line in res.stdout:gmatch "[^\n]+" do
        if line:match "^data:" then
          local payload = line:gsub("^data:%s*", "")
          if payload == "[DONE]" then
            break
          else
            local ok, decoded = pcall(vim.json.decode, payload)
            if ok and decoded then
              if decoded.choices and decoded.choices[1] then
                local delta = decoded.choices[1].delta and decoded.choices[1].delta.content
                if delta and #delta > 0 then
                  full[#full + 1] = delta
                  on_chunk(delta)
                end
              end
              if decoded.usage then
                usage = decoded.usage
              end
            end
          end
        end
      end
      on_finish(table.concat(full), usage)
    end)
  end)
end

function M.list_models()
  local cfg = config.get()
  local ttl = (cfg.models and cfg.models.cache_ttl) or 300
  local now = vim.loop.now() / 1000 -- seconds
  if (_models_cache.time + ttl) > now and #_models_cache.list > 0 then
    return _models_cache.list
  end
  local url = cfg.openrouter.base_url .. "/models"
  local ok, res = pcall(curl.get, url, { headers = headers() })
  if not ok or not res or res.status ~= 200 then
    return _models_cache.list -- return cached (maybe empty)
  end
  local okj, data = pcall(vim.json.decode, res.body)
  if not okj or type(data) ~= "table" then
    return _models_cache.list
  end
  local out = {}
  for _, m in ipairs(data.data or {}) do
    if m.id then
      out[#out + 1] = m.id
    end
  end
  table.sort(out)
  _models_cache = { time = now, list = out }
  return out
end

return M
