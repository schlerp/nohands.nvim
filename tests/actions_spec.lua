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
      picker = { session_first = false },
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
  end)

  it("uses prompt overrides for model and options", function()
    vim.cmd "enew"
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_name(buf, "test_actions_custom.lua")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hello override" })

    local used_model
    local used_opts
    local old_chat_async = api.chat_async
    api.chat_async = function(model, _messages, opts, on_success, _on_error)
      used_model = model
      used_opts = opts
      on_success "reply"
    end

    actions.run { prompt = "custom", source = "buffer" }

    api.chat_async = old_chat_async
    assert.equals("prompt-model", used_model)
    assert.is_not_nil(used_opts)
    assert.equals(0.7, used_opts.temperature)
    assert.equals(42, used_opts.max_tokens)
  end)

  it("formats non-stream output with header and response", function()
    vim.cmd "enew"
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_name(buf, "test_actions_header.lua")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "print('hi')" })

    local texts = {}
    local old_chat_async = api.chat_async
    local old_output_write = require("nohands.output").write

    api.chat_async = function(_model, _messages, _opts, on_success, _on_error)
      on_success "RESPONSE_TEXT"
    end

    require("nohands.output").write = function(method, text, incremental)
      table.insert(texts, { method = method, text = text, incremental = incremental })
      return incremental
    end

    actions.run { prompt = "explain", source = "buffer", stateless = true, output = "split" }

    api.chat_async = old_chat_async
    require("nohands.output").write = old_output_write

    assert.is_true(#texts >= 1)
    local last = texts[#texts]
    assert.matches("### Prompt: explain", last.text, 1, true)
    assert.matches("### Response", last.text, 1, true)
    assert.matches("RESPONSE_TEXT", last.text, 1, true)
  end)

  it("formats stream output with header and accumulates response", function()
    vim.cmd "enew"
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_name(buf, "test_actions_stream.lua")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "print('hi stream')" })

    local texts = {}
    local old_chat_stream = api.chat_stream
    local old_output_write = require("nohands.output").write

    api.chat_stream = function(_model, _messages, _opts, on_chunk, on_finish, _on_error)
      on_chunk "PART1_"
      on_chunk "PART2"
      on_finish("PART1_PART2", nil)
    end

    require("nohands.output").write = function(method, text, incremental)
      table.insert(texts, { method = method, text = text, incremental = incremental })
      return incremental or { buf = 1, win = 1 }
    end

    actions.run {
      prompt = "explain",
      source = "buffer",
      stateless = true,
      output = "split",
      stream = true,
    }

    api.chat_stream = old_chat_stream
    require("nohands.output").write = old_output_write

    assert.is_true(#texts >= 1)
    local final = texts[#texts]
    assert.matches("### Prompt: explain", final.text, 1, true)
    assert.matches("### Response", final.text, 1, true)
    assert.matches("PART1_PART2", final.text, 1, true)
  end)

  it("notifies token usage when enabled", function()
    vim.cmd "enew"
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_name(buf, "test_actions_usage.lua")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "print('usage')" })

    local notifications = {}
    local old_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notifications, { msg = msg, level = level })
    end

    local old_chat_async = api.chat_async
    api.chat_async = function(_model, _messages, _opts, on_success, _on_error)
      on_success("REPLY", { prompt_tokens = 10, completion_tokens = 5, total_tokens = 15 })
    end

    actions.run { prompt = "explain", source = "buffer", stateless = true }

    vim.notify = old_notify
    api.chat_async = old_chat_async

    local found = false
    for _, n in ipairs(notifications) do
      if n.msg:match "nohands: usage" then
        found = true
        assert.matches("prompt%s+10", n.msg)
        assert.matches("completion%s+5", n.msg)
        assert.matches("total%s+15", n.msg)
      end
    end
    assert.is_true(found, "Usage notification not found")
  end)

  it("does not notify token usage when disabled", function()
    config.setup {
      usage = { notify = false },
      prompts = {},
      output = { method = "split" },
    }
    vim.cmd "enew"
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_name(buf, "test_actions_no_usage.lua")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "print('usage')" })

    local notifications = {}
    local old_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notifications, { msg = msg, level = level })
    end

    local old_chat_async = api.chat_async
    api.chat_async = function(_model, _messages, _opts, on_success, _on_error)
      on_success("REPLY", { prompt_tokens = 10, completion_tokens = 5, total_tokens = 15 })
    end

    actions.run { prompt = "explain", source = "buffer", stateless = true }

    vim.notify = old_notify
    api.chat_async = old_chat_async

    for _, n in ipairs(notifications) do
      assert.is_nil(n.msg:match "nohands: usage")
    end
  end)
end)
