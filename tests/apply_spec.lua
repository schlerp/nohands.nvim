local apply = require "nohands.apply"

describe("apply diff", function()
  it("applies simple hunk additions and deletions", function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "line1", "line2", "line3" })
    local diff = [[@@ -1,3 +1,3 @@
 line1
-line2
+LINE2
 line3
]]
    apply.apply_unified(diff)
    local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.equals("line1", result[1])
    assert.equals("LINE2", result[2])
    assert.equals("line3", result[3])
  end)

  it("no diff yields notification (returns early)", function()
    apply.apply_unified "" -- nothing applied
    local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.is_true(#result > 0)
  end)
end)
