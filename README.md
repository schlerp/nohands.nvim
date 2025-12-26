# nohands.nvim

Integrate Neovim with OpenRouter models using an ergonomic picker and flexible content capture. "No hands" because the AI helps reshape code with minimal manual typing.

## Features
- Multiple content sources: buffer, visual selection, surrounding N lines, custom range (API), git diff. 
- Prompt templates (refactor, explain, tests, docstring, commit, diff_refactor) + user-defined prompts. 
- Model selection via Snacks picker (cached list; fallback to configured default if list fails). 
- Output modes: split, append, replace, float window. 
- Streaming responses (SSE) into a floating window with `:NoHandsStream` (throttled UI updates). 
- Conversation sessions to maintain context across multiple runs (optional session-first picker). 

## Installation (lazy.nvim example)
```lua
{
  'nvim-lua/plenary.nvim',
  'folke/snacks.nvim',
  {
    'schlerp/nohands.nvim',
    config = function()
      require('nohands').setup({
        model = 'openai/gpt-4o-mini',
        output = { method = 'float' },
        prompts = {
          myprompt = { name = 'myprompt', user = 'Do something special to ${content}' },
        },
      })
    end,
  },
}
```

## Environment
Set your OpenRouter API key:
```bash
export OPENROUTER_API_KEY=your_key_here
```
Optional (improves provider metadata):
```lua
require('nohands').setup({
  openrouter = {
    referer = 'https://github.com/schlerp/nohands.nvim',
    title = 'nohands.nvim',
  },
})
```

## Commands
- `:NoHands` Launch picker (session? -> prompt -> source -> model -> run).
- `:NoHandsRun [prompt]` Run immediately with default source (buffer) and optional prompt name.
- `:NoHandsStream [prompt]` Stream model output into floating window.
- `:NoHandsApplyDiff` Apply a unified diff currently displayed in buffer to the original file (single-file patch).
 
## Keymaps
By default, `setup()` defines a small set of keymaps (all configurable or disableable via the `keys` table in the config):

- Normal mode
  - `<leader>nn` → `:NoHands` (main picker)
  - `<leader>nr` → `:NoHandsRun` (buffer)
  - `<leader>ns` → `:NoHandsStream` (buffer, output in float)
  - `<leader>np` → `:NoHandsPalette`
- Visual mode
  - `<leader>nr` → `:NoHandsRun` (selection)
  - `<leader>ns` → `:NoHandsStream` (selection, output in float)

### Cheat Sheet

| Mapping | Command | Description |
|---|---|---|
| `<leader>nn` | `:NoHands` | Opens the main interactive picker to guide you through choosing a prompt, source, and model. |
| `<leader>nr` | `:NoHandsRun` | Runs the "explain" prompt on the current buffer (Normal) or selection (Visual). Useful for quick questions. |
| `<leader>ns` | `:NoHandsStream` | Same as Run, but streams the response token-by-token into a floating window. Great for long explanations. |
| `<leader>np` | `:NoHandsPalette` | Opens a command palette of all available prompts to run quickly on the current buffer. |
| `<leader>ni` | _(internal)_ | Runs the "refactor" prompt on the current buffer/selection (useful for inline code changes). |

You can change or disable these by passing a `keys` table to `setup`:

```lua
require('nohands').setup({
  keys = {
    -- change only the main picker key
    nohands = '<leader>an',

    -- disable a specific mapping by setting it to false
    run = false,
    stream = false,
    palette = false,
  },
})
```

## Lua API

```lua
local nh = require('nohands')
nh.run({ prompt = 'refactor', source = 'selection', model = 'openai/gpt-4o-mini' })
nh.run({ prompt = 'explain', stream = true, output = 'float' })
```
Session continuity:
```lua
nh.run({ session = 'mywork', prompt = 'explain' })
nh.run({ session = 'mywork', prompt = 'refactor' }) -- retains previous messages
```
Clear a session:
```lua
require('nohands').sessions.clear('mywork')
```

## Custom Prompts
```lua
require('nohands').setup({
  prompts = {
    architecture = {
      name = 'architecture',
      system = 'You analyze software architecture.',
      user = 'Review and critique the architecture choices in:\n\n${content}'
    },
  }
})
```
Each template may define `transform(content, ctx)` to pre-process input.

## Persistence & Streaming Notes
Sessions persist automatically on exit (written to `stdpath('data')/nohands_sessions.json`) and loaded on startup. Streaming uses an external `curl` process (`vim.system`). Ensure `curl` is available. SSE deltas are accumulated and the UI is throttled by `stream.flush_interval_ms`. When total accumulated characters exceed `stream.max_accumulate` earlier content is trimmed. On finish, final assistant message gets added to the session.

## Configuration Reference
```lua
require('nohands').setup({
  model = 'openai/gpt-4o-mini',
  temperature = 0.2,
  max_tokens = 800,
  openrouter = {
    base_url = 'https://openrouter.ai/api/v1',
    api_key_env = 'OPENROUTER_API_KEY',
    referer = nil,
    title = 'nohands.nvim',
  },
  prompts = {}, -- custom prompt map
  output = { method = 'split', split_direction = 'below' },
  picker = { session_first = false },
  -- default keymaps (set to false to disable, or change the lhs)
  keys = {
    nohands = '<leader>nn',
    run = '<leader>nr',
    stream = '<leader>ns',
    palette = '<leader>np',
  },
  stream = { max_accumulate = 16000, flush_interval_ms = 120 },
  diff = { write_before = true, unified = 3, async = false },
  models = { cache_ttl = 300 },
  retry = { attempts = 2, backoff_ms = 200 },
})
```

## Lua Language Server
A `.luarc.json` file declares `vim` as a global for diagnostics. Types are in `lua/nohands/types.lua`. Import not required—annotations are for tooling.

## Development

### Tooling
- Lint: `luacheck .`
- Format check: `stylua --check .`
- Apply formatting: `stylua .`

### Installing Dependencies (macOS example)
```bash
# Lua lint
luarocks install luacheck
# Stylua (choose one)
brew install stylua              # or: cargo install stylua --locked
```

### Pre-commit (recommended)
Use the pre-commit framework to enforce formatting and linting automatically.
```bash
pip install pre-commit
pre-commit install
```
The provided `.pre-commit-config.yaml` is included in the repo.
Run on all files:
```bash
pre-commit run --all-files
```

### Legacy Plain Git Hook (optional)
If using plain git hooks (no framework):
```bash
cat > .git/hooks/pre-commit <<'EOF'
#!/usr/bin/env bash
luacheck . || exit 1
stylua --check . || exit 1
EOF
chmod +x .git/hooks/pre-commit
```
Initialize git first if this directory is not yet a repo:
```bash
git init && git add . && git commit -m 'init'
```

### Optional: pre-commit Framework
Add a `.pre-commit-config.yaml` like:
```yaml
repos:
  - repo: https://github.com/JohnnyMorganz/StyLua
    rev: v0.20.0
    hooks:
      - id: stylua
  - repo: https://github.com/lunarmodules/luacheck
    rev: v1.2.0
    hooks:
      - id: luacheck
```
Then:
```bash
pip install pre-commit
pre-commit install
```

### Running CI Locally
Ensure `curl` available and run the same commands:
```bash
luacheck .
stylua --check .
```
If `stylua --check` fails, run `stylua .` then re-run checks.

## License

MIT
