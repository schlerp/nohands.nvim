local prompts = require "nohands.prompts"
local config = require "nohands.config"

describe("prompts", function()
  before_each(function()
    config.setup {
      prompts = { custom = { name = "custom", system = "sys", user = "Use this: ${content}" } },
    }
  end)

  it("lists builtin and custom prompts", function()
    local list = prompts.list()
    local names = {}
    for _, p in ipairs(list) do
      names[p.name] = true
    end
    assert.is_true(names.refactor and names.explain and names.custom)
  end)

  it("renders a prompt with content substitution", function()
    local msgs, err = prompts.render("custom", "ABC", {})
    assert.is_nil(err)
    assert.equals(2, #msgs)
    assert.equals("user", msgs[2].role)
    assert.is_not_nil(msgs[2].content:match "ABC")
  end)

  it("errors on missing prompt", function()
    local msgs, err = prompts.render("missing", "X", {})
    assert.is_nil(msgs)
    assert.is_not_nil(err)
  end)
end)
