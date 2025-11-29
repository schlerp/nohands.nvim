local sessions = require "nohands.sessions"

describe("sessions", function()
  before_each(function()
    sessions.store = {}
  end)

  it("creates default session", function()
    local s = sessions.get "abc"
    assert.equals("abc", s.id)
    assert.equals(0, #s.messages)
  end)

  it("persists and loads sessions", function()
    local s = sessions.get "persist"
    table.insert(s.messages, { role = "user", content = "Hi" })
    -- override path to temp file
    local orig = sessions._session_file
    sessions._session_file = function()
      return "tests/tmp_sessions.json"
    end
    sessions.save()
    sessions.store = {}
    sessions.load()
    local loaded = sessions.get "persist"
    assert.equals(1, #loaded.messages)
    sessions._session_file = orig
    os.remove "tests/tmp_sessions.json"
  end)

  it("clears a session", function()
    local s = sessions.get "clearme"
    table.insert(s.messages, { role = "assistant", content = "Hi" })
    sessions.clear "clearme"
    local again = sessions.get "clearme"
    assert.equals(0, #again.messages)
  end)
end)
