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

  it("wraps content in a fenced code block using buffer filetype", function()
    vim.bo.filetype = "lua"
    local msgs, err = prompts.render("custom", "ABC", {})
    assert.is_nil(err)
    assert.equals(2, #msgs)
    local user_content = msgs[2].content
    assert.is_not_nil(user_content:match "```lua")
    assert.is_not_nil(user_content:match "ABC")
    assert.is_not_nil(user_content:match "```")
  end)

  it("uses diff language fence when meta type is diff", function()
    vim.bo.filetype = "lua"
    local msgs, err = prompts.render("custom", "DIFF", { meta = { type = "diff" } })
    assert.is_nil(err)
    assert.equals(2, #msgs)
    local user_content = msgs[2].content
    assert.is_not_nil(user_content:match "```diff")
    assert.is_not_nil(user_content:match "DIFF")
  end)

  it("errors on missing prompt", function()
    local msgs, err = prompts.render("missing", "X", {})
    assert.is_nil(msgs)
    assert.is_not_nil(err)
  end)
end)
