-- Types centralised in types.lua

local M = {}

local function join_lines(lines)
  return table.concat(lines, "\n")
end

---@param bufnr? integer
---@return NoHandsContent
function M.buffer(bufnr)
  if type(bufnr) ~= "number" or not vim.api.nvim_buf_is_valid(bufnr or -1) then
    bufnr = vim.api.nvim_get_current_buf()
  end
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return {
    text = join_lines(lines),
    meta = { type = "buffer", bufnr = bufnr, path = vim.api.nvim_buf_get_name(bufnr) },
  }
end

---@return NoHandsContent
function M.selection()
  local mode = vim.fn.mode()
  local spos
  local epos
  if mode:match "v" then
    spos = vim.fn.getpos "v"
    epos = vim.fn.getpos "."
  else
    spos = vim.fn.getpos "'<"
    epos = vim.fn.getpos "'>"
  end
  local _, sline, scol, _ = unpack(spos)
  local _, eline, ecol, _ = unpack(epos)

  -- Normalize so start <= end in buffer order
  if sline > eline or (sline == eline and scol > ecol) then
    sline, eline = eline, sline
    scol, ecol = ecol, scol
  end

  local start_line = sline - 1
  local end_line = eline - 1
  local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line + 1, false)
  if #lines == 0 then
    return {
      text = "",
      meta = { type = "selection", range = { start_line = start_line, end_line = end_line } },
    }
  end
  if #lines == 1 then
    lines[1] = string.sub(lines[1], scol, ecol)
  else
    lines[1] = string.sub(lines[1], scol)
    lines[#lines] = string.sub(lines[#lines], 1, ecol)
  end
  return {
    text = join_lines(lines),
    meta = { type = "selection", range = { start_line = start_line, end_line = end_line } },
  }
end

---@param before? integer
---@param after? integer
---@return NoHandsContent
function M.surrounding(before, after)
  before = before or 10
  after = after or 10
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cur_line = cursor[1] - 1
  local start_line = math.max(cur_line - before, 0)
  local end_line = cur_line + after + 1
  local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line, false)
  return {
    text = join_lines(lines),
    meta = { type = "surrounding", center = cur_line, before = before, after = after },
  }
end

---@param start_line integer
---@param end_line integer
---@return NoHandsContent
function M.range(start_line, end_line)
  local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line + 1, false)
  return {
    text = join_lines(lines),
    meta = { type = "range", start_line = start_line, end_line = end_line },
  }
end

M.sources = {
  buffer = M.buffer,
  selection = M.selection,
  surrounding = function(opts)
    return M.surrounding(opts.before, opts.after)
  end,
  range = function(opts)
    return M.range(opts.start_line, opts.end_line)
  end,
  diff = function(opts)
    local cfg = require("nohands.config").get().diff
    local bufnr = vim.api.nvim_get_current_buf()
    if cfg.write_before and vim.bo.modified then
      vim.cmd "write"
    end
    local filename = vim.api.nvim_buf_get_name(bufnr)
    if filename == "" then
      return M.buffer(bufnr)
    end
    local unified = cfg.unified or 3
    local h = io.popen(
      "git diff --no-color --unified=" .. unified .. " -- " .. vim.fn.fnameescape(filename)
    )
    local diff = h and h:read "*a" or ""
    if h then
      h:close()
    end
    if diff == "" then
      return { text = "No diff for file.", meta = { type = "diff", path = filename } }
    end
    return { text = diff, meta = { type = "diff", path = filename } }
  end,
  lsp_symbol = function(_opts)
    local params = vim.lsp.util.make_range_params()
    local bufnr = params.textDocument and vim.uri_to_bufnr(params.textDocument.uri)
      or vim.api.nvim_get_current_buf()
    local clients = vim.lsp.get_active_clients { bufnr = bufnr }
    if #clients == 0 then
      return M.buffer(bufnr)
    end
    local client = clients[1]
    local ok, result = pcall(client.request_sync, client, "textDocument/documentSymbol", {
      textDocument = { uri = vim.uri_from_bufnr(bufnr) },
    }, 1000, bufnr)
    if not ok or not result or not result.result then
      return M.buffer(bufnr)
    end
    local symbols = result.result or {}
    local cursor = vim.api.nvim_win_get_cursor(0)
    local cur_line = cursor[1] - 1
    local best
    local function pick_from_range(range)
      local s = range.start.line
      local e = range["end"].line
      if cur_line >= s and cur_line <= e then
        if not best or (s >= best.start_line and e <= best.end_line) then
          best = { start_line = s, end_line = e }
        end
      end
    end
    local function visit(list)
      for _, item in ipairs(list or {}) do
        if item.range then
          pick_from_range(item.range)
        end
        if item.selectionRange then
          pick_from_range(item.selectionRange)
        end
        if item.children then
          visit(item.children)
        end
      end
    end
    visit(symbols)
    if not best then
      return M.buffer(bufnr)
    end
    return M.range(best.start_line, best.end_line)
  end,
  diagnostic = function(_opts)
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1] - 1
    local diags = vim.diagnostic.get(bufnr, { lnum = line })
    if #diags == 0 then
      return M.buffer(bufnr)
    end
    local lines = {}
    for _, d in ipairs(diags) do
      lines[#lines + 1] = string.format("[%s] %s", d.severity or "", d.message or "")
    end
    return {
      text = join_lines(lines),
      meta = { type = "diagnostic", bufnr = bufnr, line = line },
    }
  end,
  quickfix = function(_opts)
    local items = vim.fn.getqflist() or {}
    if #items == 0 then
      return M.buffer()
    end
    local lines = {}
    for _, it in ipairs(items) do
      local lnum = it.lnum or 0
      local col = it.col or 0
      local text = it.text or ""
      lines[#lines + 1] = string.format("%s:%d:%d: %s", it.filename or "", lnum, col, text)
    end
    return {
      text = join_lines(lines),
      meta = { type = "quickfix" },
    }
  end,
}

---@param source string
---@param opts? table
---@return NoHandsContent
function M.get(source, opts)
  local fn = M.sources[source]
  if not fn then
    return M.buffer()
  end
  return fn(opts or {})
end

return M
