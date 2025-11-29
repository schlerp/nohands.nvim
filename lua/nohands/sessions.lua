local M = {}

---@type table<string, NoHandsSession>
M.store = {}

local function new_session(id)
  M.store[id] = { id = id, messages = {} }
  return M.store[id]
end

---@param id string|nil
---@return NoHandsSession
function M.get(id)
  id = id or "default"
  return M.store[id] or new_session(id)
end

---@param id string
function M.clear(id)
  M.store[id] = nil
end

function M._session_file()
  return vim.fn.stdpath "data" .. "/nohands_sessions.json"
end

function M.save()
  local ok, encoded = pcall(vim.json.encode, M.store)
  if not ok then
    return
  end
  local f = io.open(M._session_file(), "w")
  if not f then
    return
  end
  f:write(encoded)
  f:close()
end

function M.load()
  local f = io.open(M._session_file(), "r")
  if not f then
    return
  end
  local content = f:read "*a"
  f:close()
  local ok, data = pcall(vim.json.decode, content)
  if ok and type(data) == "table" then
    M.store = data
  end
end

return M
