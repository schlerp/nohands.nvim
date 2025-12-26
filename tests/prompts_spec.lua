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

  it("injects full_buffer context when provided", function()
    local tmpl_str = "Code: ${content}\nContext: ${full_buffer}"
    config.setup {
      prompts = { context_test = { name = "context_test", system = "sys", user = tmpl_str } },
    }
    local msgs, err =
      prompts.render("context_test", "SNIPPET", { full_buffer = "FULL_FILE_CONTENT" })
    assert.is_nil(err)
    local user_content = msgs[2].content
    assert.is_not_nil(user_content:match "Code:.*SNIPPET")
    assert.is_not_nil(user_content:match "Context: FULL_FILE_CONTENT")
  end)

  it("removes reference section from refactor prompt when full_buffer is missing", function()
    -- reset config to ensure we use builtin
    config.setup { prompts = {} }

    -- Case 1: No full_buffer
    local msgs1, _ = prompts.render("refactor", "CODE", {})
    assert.is_nil(msgs1[2].content:match "Reference %(Full File%)")

    -- Case 2: With full_buffer
    local msgs2, _ = prompts.render("refactor", "CODE", { full_buffer = "FULL" })
    assert.is_not_nil(msgs2[2].content:match "Reference %(Full File%)")
    assert.is_not_nil(msgs2[2].content:match "FULL")
  end)

  it("safely handles special characters (percent signs) in full_buffer injection", function()
    -- This test ensures that code with % (like string.format("%s")) doesn't break gsub
    local special_code = 'local x = string.format("%s %d", "val", 10)'
    local msgs, err = prompts.render("refactor", "CODE", { full_buffer = special_code })
    assert.is_nil(err)

    local content = msgs[2].content
    -- If not escaped properly, %s might be lost or interpreted as a capture
    assert.is_not_nil(content:find(special_code, 1, true), "Should contain the exact code string")
  end)

  it("appends language specific instructions", function()
    vim.bo.filetype = "python"
    config.setup {
      language_instructions = { python = "PYTHON_INSTR" },
      prompts = { custom = { name = "custom", system = "sys", user = "${content}" } },
    }
    local msgs, err = prompts.render("custom", "CODE", {})
    assert.is_nil(err)
    assert.is_not_nil(msgs[2].content:match "Language Specific Instructions:")
    assert.is_not_nil(msgs[2].content:match "PYTHON_INSTR")
  end)

  it("errors on missing prompt", function()
    local msgs, err = prompts.render("missing", "X", {})
    assert.is_nil(msgs)
    assert.is_not_nil(err)
  end)
end)
