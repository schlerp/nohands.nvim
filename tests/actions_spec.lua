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

  it("uses prompt-specific model and options when provided", function()
    local used_model
    local used_opts
    local old_chat = api.chat
    api.chat = function(model, _, user_opts)
      used_model = model
      used_opts = user_opts
      return "REPLY2", nil
    end
    config.setup {
      model = "base-model",
      temperature = 0.0,
      max_tokens = 5,
      openrouter = { base_url = "x", api_key_env = "OPENROUTER_API_KEY" },
      output = { method = "split", split_direction = "below" },
      picker = { use_snacks = false, session_first = false },
      stream = { max_accumulate = 16000, flush_interval_ms = 50 },
      diff = { write_before = false, unified = 3, async = false },
      models = { cache_ttl = 1 },
      retry = { attempts = 1, backoff_ms = 0 },
      prompts = {
        custom = {
          name = "custom",
          user = "${content}",
          model = "prompt-model",
          temperature = 0.7,
          max_tokens = 42,
        },
      },
    }
    sessions.store = {}
    vim.cmd "enew"
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_name(buf, "test_actions_custom.lua")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hello override" })
    actions.run { prompt = "custom", source = "buffer" }
    api.chat = old_chat
    assert.equals("prompt-model", used_model)
    assert.is_not_nil(used_opts)
    assert.equals(0.7, used_opts.temperature)
    assert.equals(42, used_opts.max_tokens)
  end)
end)
