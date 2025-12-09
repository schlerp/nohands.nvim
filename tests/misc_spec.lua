local nh = require "nohands"

describe("init module", function()
  it("exposes setup and run", function()
    assert.is_not_nil(nh.setup)
    assert.is_not_nil(nh.run)
  end)

  it("setup updates config table", function()
    local old_model = nh.get_config().model
    nh.setup {
      model = "custom/model",
      temperature = 0.1,
      max_tokens = 10,
      openrouter = { base_url = "https://example", api_key_env = "OPENROUTER_API_KEY" },
      output = { method = "split", split_direction = "below" },
      picker = { session_first = false },
      stream = { max_accumulate = 16000, flush_interval_ms = 120 },
      diff = { write_before = true, unified = 3, async = false },
      models = { cache_ttl = 60 },
      retry = { attempts = 1, backoff_ms = 0 },
      prompts = {},
    }
    assert.equals("custom/model", nh.get_config().model)
    assert.not_equals(old_model, nh.get_config().model)
  end)
end)
