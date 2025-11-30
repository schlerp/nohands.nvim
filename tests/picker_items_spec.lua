-- Stub API BEFORE requiring picker to avoid real curl calls
package.preload["nohands.api"] = function()
  return {
    chat = function(_, messages)
      return "stub-response for " .. #messages .. " messages"
    end,
    chat_stream = function() end,
    list_models = function()
      return { "modelA", "modelB" }
    end,
  }
end

local config = require "nohands.config"

-- Capture items from Snacks picker
local captured = {}
package.preload["snacks"] = function()
  return {
    picker = {
      pick = function(opts)
        table.insert(
          captured,
          { title = opts.title, count = #(opts.items or {}), items = opts.items }
        )
        if opts.confirm and opts.items and opts.items[1] then
          opts.confirm(nil, opts.items[1])
        end
        return {}
      end,
    },
  }
end

local picker = require "nohands.picker"

describe("picker items visibility", function()
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
    vim.api.nvim_buf_set_name(buf, "item_test.lua")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line1", "line2" })
  end)

  it("passes non-empty items to each picker stage", function()
    picker.open()
    assert.is_true(#captured >= 3, "expected three picker invocations (prompt, source, model)")
    assert.is_true(captured[1].count > 0, "prompt picker should have items")
    assert.is_true(captured[2].count > 0, "source picker should have items")
    assert.is_true(captured[3].count > 0, "model picker should have items")
  end)
end)
