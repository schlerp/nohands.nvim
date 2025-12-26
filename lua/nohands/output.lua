local config = require "nohands.config"
local utils = require "nohands.utils"

local M = {}

--- Render model output to Neovim using the configured method.
---@param method 'split'|'append'|'replace'|'float'|'diff'
---@param text string
---@param incremental? { buf: integer }
---@param meta? table
---@return table|nil state
function M.write(method, text, incremental, meta)
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
    if meta and meta.range then
      local sline = meta.range.start_line
      local eline = meta.range.end_line
      local new_lines = vim.split(text, "\n")
      -- Determine if we need to handle column-wise replacement (partial lines)
      if meta.col_start and meta.col_end then
        -- We need to read the buffer to stitch the lines
        local buf_lines = vim.api.nvim_buf_get_lines(0, sline, eline + 1, false)
        if #buf_lines > 0 then
          local first_line = buf_lines[1]
          local last_line = buf_lines[#buf_lines]
          -- col_start is 1-based index from getpos?
          -- content.lua:
          --   spos = vim.fn.getpos "v" -> [bufnum, lnum, col, off]
          --   ...
          --   local _, sline, scol, _ = unpack(spos)
          --   lines[1] = string.sub(lines[1], scol, ecol)
          -- So scol/ecol are 1-based.
          -- But string.sub(s, 1, scol-1) gets prefix.

          local prefix = string.sub(first_line, 1, meta.col_start - 1)
          local suffix = string.sub(last_line, meta.col_end + 1)

          -- Construct new lines
          if #new_lines == 1 then
            new_lines[1] = prefix .. new_lines[1] .. suffix
          else
            new_lines[1] = prefix .. new_lines[1]
            new_lines[#new_lines] = new_lines[#new_lines] .. suffix
          end
        end
      end
      vim.api.nvim_buf_set_lines(0, sline, eline + 1, false, new_lines)
      return nil
    end

    if utils.is_visual_mode() then
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
  elseif method == "diff" then
    -- Extract code block if present
    local extracted = text:match "```%w*\n(.-)\n```"
    if extracted then
      text = extracted
    end

    local target_buf = vim.api.nvim_get_current_buf()
    local target_lines = vim.api.nvim_buf_get_lines(target_buf, 0, -1, false)
    local new_text_lines = vim.split(text, "\n")
    local result_lines = {}

    if meta and meta.range then
      local s = meta.range.start_line -- 0-based
      local e = meta.range.end_line -- 0-based

      -- Add lines before start
      for i = 1, s do
        table.insert(result_lines, target_lines[i])
      end

      if meta.col_start and meta.col_end then
        -- Character splice
        local first_line = target_lines[s + 1] or ""
        local last_line = target_lines[e + 1] or ""
        local prefix = string.sub(first_line, 1, meta.col_start - 1)
        local suffix = string.sub(last_line, meta.col_end + 1)

        if #new_text_lines == 1 then
          table.insert(result_lines, prefix .. new_text_lines[1] .. suffix)
        else
          table.insert(result_lines, prefix .. new_text_lines[1])
          for i = 2, #new_text_lines - 1 do
            table.insert(result_lines, new_text_lines[i])
          end
          table.insert(result_lines, new_text_lines[#new_text_lines] .. suffix)
        end
      else
        -- Line splice
        for _, line in ipairs(new_text_lines) do
          table.insert(result_lines, line)
        end
      end

      -- Add lines after end
      for i = e + 2, #target_lines do
        table.insert(result_lines, target_lines[i])
      end
    else
      -- If no range metadata (e.g. from buffer source), assume full file replacement
      -- However, if we're diffing against a selection without range info, we might have issues.
      -- But usually 'selection' source provides range metadata.
      -- If the prompt didn't use a source with range metadata, we might just be diffing against
      -- the prompt result itself vs the whole file?
      -- If text is partial but we lack metadata, we can't reconstruct the file.
      -- Assuming prompts that use 'diff' output will use sources that provide range metadata or full file.
      result_lines = new_text_lines
    end

    local buf = vim.api.nvim_create_buf(false, true)

    -- Populate the scratch buffer with the FULL reconstructed file content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, result_lines)

    local target_ft = vim.bo[target_buf].filetype
    vim.api.nvim_buf_set_option(buf, "filetype", target_ft)

    local win_opts = {
      split = "right",
    }
    local win = vim.api.nvim_open_win(buf, true, win_opts)

    -- Setup diff
    vim.cmd "diffthis"
    local orig_win = vim.fn.win_getid(vim.fn.winnr "#")
    if orig_win ~= 0 and vim.api.nvim_win_is_valid(orig_win) then
      vim.api.nvim_set_current_win(orig_win)
      vim.cmd "diffthis"
      vim.api.nvim_set_current_win(win)
    end

    -- Help message
    local help_lines = {
      "# Refactor Preview",
      "#",
      "# [y] Accept  [n] Discard  [q] Close",
      "",
    }
    local old_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local all_lines = {}
    for _, l in ipairs(help_lines) do
      table.insert(all_lines, l)
    end
    for _, l in ipairs(old_lines) do
      table.insert(all_lines, l)
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, all_lines)

    local function cleanup()
      vim.cmd "diffoff"
      if vim.api.nvim_win_is_valid(orig_win) then
        vim.api.nvim_set_current_win(orig_win)
        vim.cmd "diffoff"
      end
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end

    vim.keymap.set("n", "y", function()
      cleanup()
      -- Remove help lines before applying
      local content = vim.api.nvim_buf_get_lines(buf, #help_lines, -1, false)
      vim.api.nvim_buf_set_lines(target_buf, 0, -1, false, content)
      vim.notify("Changes applied", vim.log.levels.INFO)
    end, { buffer = buf, desc = "Accept changes" })

    vim.keymap.set("n", "n", function()
      cleanup()
      vim.notify("Changes discarded", vim.log.levels.INFO)
    end, { buffer = buf, desc = "Discard changes" })

    vim.keymap.set("n", "q", function()
      cleanup()
    end, { buffer = buf, desc = "Close diff view" })

    return { buf = buf, win = win }
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
    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      row = row,
      col = col,
      width = width,
      height = height,
      style = "minimal",
      border = "rounded",
    })
    vim.api.nvim_buf_set_option(buf, "filetype", "markdown")

    -- Add keymap to close window
    vim.keymap.set("n", "q", function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, { buffer = buf, nowait = true })

    return { buf = buf, win = win }
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
