local output = require "nohands.output"
local assert = require "luassert"

describe("output.write", function()
  before_each(function()
    vim.cmd "enew" -- Clear buffer
  end)

  describe("method='diff'", function()
    it("creates a vertical split with diffthis enabled", function()
      -- Setup initial buffer
      local lines = { "local x = 1", "print(x)" }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      local target_buf = vim.api.nvim_get_current_buf()

      -- Call write
      local state = output.write("diff", "local x = 2\nprint(x)")

      -- Verify new window/buffer
      assert.is_not_nil(state)
      assert.is_not_nil(state.win)
      assert.is_not_nil(state.buf)
      assert.are_not.equal(target_buf, state.buf)

      -- Check diff option is set in both windows
      local is_diff = vim.api.nvim_win_get_option(state.win, "diff")
      assert.is_true(is_diff)

      -- Clean up
      if vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_close(state.win, true)
      end
    end)

    it("extracts code blocks from markdown", function()
      local markdown = "Here is the code:\n```lua\nreturn true\n```\n"
      local state = output.write("diff", markdown)
      assert.is_not_nil(state)

      -- It should contain help lines now too
      local content = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
      -- First 4 lines are help
      assert.are.same("# Refactor Preview", content[1])

      -- Content should be later
      local found = false
      for _, l in ipairs(content) do
        if l == "return true" then
          found = true
        end
      end
      assert.is_true(found)

      if vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_close(state.win, true)
      end
    end)

    it("accepts changes (y) for whole buffer", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "old" })
      local target_buf = vim.api.nvim_get_current_buf()

      local state = output.write("diff", "new")
      assert.is_not_nil(state)

      local maps = vim.api.nvim_buf_get_keymap(state.buf, "n")
      local y_map
      for _, map in ipairs(maps) do
        if map.lhs == "y" then
          y_map = map
        end
      end

      assert.is_not_nil(y_map)
      assert.is_not_nil(y_map.callback)

      -- Execute the callback
      y_map.callback()

      -- Check target buffer changed
      local result = vim.api.nvim_buf_get_lines(target_buf, 0, -1, false)
      assert.are.same({ "new" }, result)

      -- Check diff window closed
      assert.is_false(vim.api.nvim_win_is_valid(state.win))
    end)

    it("handles partial line replacement with meta.col_start", function()
      local lines = { "local foo = 1", "local bar = 2" }
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      local target_buf = vim.api.nvim_get_current_buf()

      -- Simulate selecting "foo = 1" on line 1.
      -- "local " is chars 1-6 (including space). "foo" starts at 7.
      -- "foo = 1" ends at 13.
      local meta = {
        range = { start_line = 0, end_line = 0 },
        col_start = 7,
        col_end = 13,
      }

      -- Write diff.
      -- Old: local foo = 1
      -- New: local baz = 3
      local state = output.write("diff", "baz = 3", nil, meta)
      assert.is_not_nil(state)

      -- Check that the scratch buffer contains the FULL file with the change (plus help)
      local scratch_content = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
      local found_change = false
      for _, l in ipairs(scratch_content) do
        if l == "local baz = 3" then
          found_change = true
        end
      end
      assert.is_true(found_change)

      -- Apply changes
      local maps = vim.api.nvim_buf_get_keymap(state.buf, "n")
      local y_map
      for _, map in ipairs(maps) do
        if map.lhs == "y" then
          y_map = map
        end
      end

      assert.is_not_nil(y_map)
      y_map.callback()

      local result = vim.api.nvim_buf_get_lines(target_buf, 0, -1, false)
      assert.are.same({ "local baz = 3", "local bar = 2" }, result)
    end)
  end)
end)
