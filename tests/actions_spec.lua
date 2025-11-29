local actions = require "nohands.actions"
local sessions = require "nohands.sessions"
local config = require "nohands.config"
local api = require "nohands.api"

describe("actions.run", function()
  before_each(function()
    config.setup {
      model = "m",
      temperature = 0.0,
      max_tokens = 5,
      openrouter = { base_url = "x", api_key_env = "OPENROUTER_API_KEY" },
      output = { method = "split", split_direction = "below" },
      picker = { use_snacks = false, session_first = false },
      stream = { max_accumulate = 16000, flush_interval_ms = 50 },
      diff = { write_before = false, unified = 3, async = false },
      models = { cache_ttl = 1 },
      retry = { attempts = 1, backoff_ms = 0 },
      prompts = {},
    }
    sessions.store = {}
  end)

  it("appends assistant message after chat", function()
    local old_chat = api.chat
    api.chat = function(_, _, _)
      return "REPLY", nil
    end
    vim.cmd "enew"
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_name(buf, "test_actions.lua")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hello world" })
    actions.run { prompt = "explain", source = "buffer" }
    local s = sessions.get "default"
    api.chat = old_chat
    local found = false
    for _, m in ipairs(s.messages) do
      if m.role == "assistant" and m.content == "REPLY" then
        found = true
      end
    end
    assert.is_true(found)
  end)
end)
