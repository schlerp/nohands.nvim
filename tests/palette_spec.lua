local config = require "nohands.config"
local picker = require "nohands.picker"

-- Capture palette invocations when using the Snacks picker
local captured = {}

-- picker_items_spec defines the Snacks stub; here we only observe
package.loaded.snacks = {
  picker = {
    ---@param items any[]
    ---@param opts table|nil
    ---@param on_choice fun(item:any|nil)
    select = function(items, opts, on_choice)
      local rec = {
        title = opts and opts.prompt or "",
        items = items or {},
      }
      table.insert(captured, rec)
      if items and items[1] and on_choice then
        on_choice(items[1])
      elseif on_choice then
        on_choice(nil)
      end
    end,
  },
}

describe("palette", function()
  before_each(function()
    captured = {}
    config.setup {
      model = "m",
      temperature = 0,
      max_tokens = 5,
      openrouter = { base_url = "x", api_key_env = "OPENROUTER_API_KEY" },
      output = { method = "split", split_direction = "below" },
      picker = { use_snacks = true, session_first = false },
      stream = { max_accumulate = 16000, flush_interval_ms = 50 },
      diff = { write_before = false, unified = 3, async = false },
      models = { cache_ttl = 1 },
      retry = { attempts = 1, backoff_ms = 0 },
      prompts = { one = { name = "one", user = "${content}" } },
    }
    vim.cmd "enew"
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_name(buf, "palette_test.lua")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line1", "line2" })
  end)

  it("shows prompts as palette items", function()
    picker.palette()
    assert.is_true(#captured >= 1)
    local opts = captured[1]
    assert.equals("nohands: palette", opts.title)
    assert.is_true(#opts.items > 0)
  end)
end)
