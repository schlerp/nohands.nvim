local picker = require "nohands.picker"
local config = require "nohands.config"
local sessions = require "nohands.sessions"

-- snacks stub provided in minimal_init

describe("picker", function()
  before_each(function()
    config.setup {
      model = "x",
      temperature = 0,
      max_tokens = 5,
      openrouter = { base_url = "x", api_key_env = "OPENROUTER_API_KEY" },
      output = { method = "split", split_direction = "below" },
      picker = { use_snacks = true, session_first = false },
      stream = { max_accumulate = 16000, flush_interval_ms = 50 },
      diff = { write_before = false, unified = 3, async = false },
      models = { cache_ttl = 1 },
      retry = { attempts = 1, backoff_ms = 0 },
      prompts = {},
    }
    sessions.store = {}
  end)

  it("opens picker and triggers flow", function()
    -- add a prompt so picker has items
    config.setup { prompts = { one = { name = "one", user = "${content}" } } }
    vim.cmd "enew"
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_name(buf, "test_picker.lua")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "buffer content" })
    picker.open()
    -- default session should exist even if nothing executed due to stub
    local s = sessions.get "default"
    assert.is_true(s.id == "default")
  end)
end)
