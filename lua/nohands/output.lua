local config = require "nohands.config"

local M = {}

--- Render model output to Neovim using the configured method.
---@param method 'split'|'append'|'replace'|'float'
---@param text string
---@param incremental? { buf: integer }
---@return table|nil state
function M.write(method, text, incremental)
  -- For replace/append, ask before mutating the current buffer.
  if method == "replace" or method == "append" then
    local choice = vim.fn.confirm(
      "nohands: apply response to current buffer?",
      "&Yes\n&No (show in temp buffer)",
      2
    )
    if choice ~= 1 then
      method = "split"
    end
  end

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
      return nil
    end
    local line = vim.api.nvim_win_get_cursor(0)[1] - 1
    local new_lines = vim.split(text, "\n")
    vim.api.nvim_buf_set_lines(0, line, line + 1, false, new_lines)
    return nil
  elseif method == "append" then
    local line = vim.api.nvim_win_get_cursor(0)[1]
    local new_lines = vim.split(text, "\n")
    vim.api.nvim_buf_set_lines(0, line, line, false, new_lines)
    return nil
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
    local height = math.floor(vim.o.lines * 0.8)
    if height < 3 then
      height = 3
    end
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

    if
      incremental
      and incremental.buf
      and incremental.win
      and vim.api.nvim_buf_is_valid(incremental.buf)
      and vim.api.nvim_win_is_valid(incremental.win)
    then
      local lines = vim.split(text, "\n")
      vim.api.nvim_buf_set_lines(incremental.buf, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(incremental.buf, "filetype", "markdown")
      vim.api.nvim_win_set_cursor(incremental.win, { 1, 0 })
      return incremental
    end

    if direction == "right" then
      local old_splitright = vim.o.splitright
      if not old_splitright then
        vim.o.splitright = true
      end
      local ok, err = pcall(vim.cmd, "vsplit")
      vim.o.splitright = old_splitright
      if not ok then
        error(err)
      end
    else
      vim.cmd "split"
    end
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(win, buf)
    local lines = vim.split(text, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
    vim.api.nvim_win_set_cursor(win, { 1, 0 })
    return { buf = buf, win = win }
  end
end

return M
