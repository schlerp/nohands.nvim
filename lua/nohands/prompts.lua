local config = require "nohands.config"
local M = {}

---@type table<string, NoHandsPromptTemplate>
M.builtin = {
  refactor = {
    name = "refactor",
    system = "You are an expert software engineer improving code quality.",
    user = "Refactor the following code for clarity and performance. Preserve behavior.\n\n${content}",
  },
  explain = {
    name = "explain",
    system = "You explain code clearly and concisely.",
    user = "Explain what the following code does.\n\n${content}",
  },
  tests = {
    name = "tests",
    system = "You write high quality tests.",
    user = "Write unit tests for the following code. Use appropriate framework hints only.\n\n${content}",
  },
  docstring = {
    name = "docstring",
    system = "You write clear documentation.",
    user = "Generate a concise docstring for the following function(s).\n\n${content}",
  },
  commit = {
    name = "commit",
    system = "You summarize changes for commit messages.",
    user = "Generate a conventional commit subject + body for the diff or code."
      .. "\n\n${content}",
  },
  diff_refactor = {
    name = "diff_refactor",
    system = "You produce improved code patches from unified diffs. Output only a diff if changes are needed.",
    user = "Analyze the unified diff and refine if helpful; otherwise say no changes."
      .. "\n\n${content}",
  },
}

local function merge_prompts()
  local user = config.get().prompts or {}
  local merged = {}
  for k, v in pairs(M.builtin) do
    merged[k] = v
  end
  for k, v in pairs(user) do
    merged[k] = v
  end
  return merged
end

---@return NoHandsPromptTemplate[]
function M.list()
  local all = merge_prompts()
  local out = {}
  for _, v in pairs(all) do
    out[#out + 1] = v
  end
  table.sort(out, function(a, b)
    return a.name < b.name
  end)
  return out
end

---@param name string
---@return NoHandsPromptTemplate|nil
function M.get(name)
  return merge_prompts()[name]
end

---@param prompt_name string
---@param content string
---@param ctx table
---@return table|nil messages, string|nil error
function M.render(prompt_name, content, ctx)
  local tmpl = M.get(prompt_name)
  if not tmpl then
    return nil, "Prompt " .. prompt_name .. " not found"
  end
  local processed = content
  if tmpl.transform then
    local ok, newc = pcall(tmpl.transform, content, ctx)
    if ok and type(newc) == "string" then
      processed = newc
    end
  end
  local user_text = (tmpl.user or "${content}"):gsub("${content}", processed)
  local messages = {}
  if tmpl.system then
    table.insert(messages, { role = "system", content = tmpl.system })
  end
  table.insert(messages, { role = "user", content = user_text })
  return messages
end

return M
