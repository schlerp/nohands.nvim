local M = {}

-- Apply a unified diff (single-file) to current buffer.
-- Handles multiple hunks. Simplified: ignores file header lines (---/+++).
-- Returns true on any applied change, false if diff empty or invalid.
function M.apply_unified(diff_text)
  if type(diff_text) ~= "string" or diff_text == "" then
    vim.notify("nohands: empty diff", vim.log.levels.WARN)
    return false
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local original = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local new = vim.deepcopy(original)
  local lines = vim.split(diff_text, "\n")
  local idx = 1
  local applied = false
  while idx <= #lines do
    local header = lines[idx]
    if header:match "^@@" then
      -- @@ -old_start,old_len +new_start,new_len @@
      local old_start_s, old_len_s = header:match "@@ %-(%d+),?(%d*) %+%d+,?%d* @@"
      local old_start = tonumber(old_start_s)
      local _declared_old_len = tonumber(old_len_s ~= "" and old_len_s or "1")
      idx = idx + 1
      if not old_start then
        -- malformed header; skip until next header
        while idx <= #lines and not lines[idx]:match "^@@" do
          idx = idx + 1
        end
      else
        local hunk_lines = {}
        while idx <= #lines and not lines[idx]:match "^@@" and lines[idx] ~= "" do
          table.insert(hunk_lines, lines[idx])
          idx = idx + 1
        end
        -- Build replacement and count consumed original lines
        local replacement = {}
        local consumed = 0
        for _, hl in ipairs(hunk_lines) do
          local prefix = hl:sub(1, 1)
          local content = hl:sub(2)
          if prefix == " " then
            consumed = consumed + 1
            replacement[#replacement + 1] = content
          elseif prefix == "-" then
            consumed = consumed + 1
          elseif prefix == "+" then
            replacement[#replacement + 1] = content
          end
        end
        -- Fallback: if consumed zero use declared length
        if consumed == 0 then
          consumed = _declared_old_len or 0
        end
        -- Splice
        local remove_at = old_start -- diff indices are 1-based
        for _ = 1, consumed do
          if new[remove_at] then
            table.remove(new, remove_at)
          end
        end
        for i, l in ipairs(replacement) do
          table.insert(new, remove_at + i - 1, l)
        end
        applied = true
      end
    else
      idx = idx + 1
    end
  end
  if applied then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new)
    vim.notify("nohands: diff applied", vim.log.levels.INFO)
  else
    vim.notify("nohands: no applicable hunks", vim.log.levels.WARN)
  end
  return applied
end

return M
