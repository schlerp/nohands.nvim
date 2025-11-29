local api = require "nohands.api"
local config = require "nohands.config"

describe("api", function()
  before_each(function()
    config.setup {
      model = "test/model",
      temperature = 0.1,
      max_tokens = 10,
      openrouter = { base_url = "https://example", api_key_env = "OPENROUTER_API_KEY" },
      output = { method = "split", split_direction = "below" },
      picker = { use_snacks = false, session_first = false },
      stream = { max_accumulate = 16000, flush_interval_ms = 120 },
      diff = { write_before = true, unified = 3, async = false },
      models = { cache_ttl = 1 },
      retry = { attempts = 1, backoff_ms = 0 },
    }
  end)

  it("chat returns content on success", function()
    local curl = require "plenary.curl"
    local old_post = curl.post
    curl.post = function(_, _)
      return {
        status = 200,
        body = vim.json.encode { choices = { { message = { content = "Hi" } } } },
      }
    end
    local out, err = api.chat(nil, { { role = "user", content = "Hello" } }, nil)
    curl.post = old_post
    assert.is_nil(err)
    assert.equals("Hi", out)
  end)

  it("chat returns error on failure", function()
    local curl = require "plenary.curl"
    local old_post = curl.post
    curl.post = function(_, _)
      return { status = 500, body = "fail" }
    end
    local out, err = api.chat(nil, { { role = "user", content = "Hello" } }, nil)
    curl.post = old_post
    assert.is_nil(out)
    assert.is_not_nil(err:match "HTTP")
  end)
end)
