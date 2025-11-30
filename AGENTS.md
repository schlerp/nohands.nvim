# AGENTS.md (nohands.nvim)

1. Tests (full): `nvim --headless -c "set rtp+=$(pwd)/plenary" -c "lua require('plenary.test_harness').test_directory('tests', { minimal_init = 'tests/minimal_init.lua' })" -c qa`
2. Single test file: replace `test_directory('tests'` with e.g. `'tests/api_spec.lua'`.
3. Lint: `luacheck lua tests` (std=luajit; global `vim` allowed).
4. Format check: `stylua --check lua tests`; apply: `stylua .`.
5. Pre-commit hooks run Stylua and Luacheck; keep code passing both.
6. Imports: prefer `local M = {}` module pattern; only require once per file; cache `require` results.
7. Naming: snake_case for locals/fields; UpperCamelCase only for type aliases in annotations; avoid one-letter names.
8. Types: use EmmyLua `---@class` / `---@field`; keep in `lua/nohands/types.lua`; return `{}` when file only holds annotations.
9. Error handling: use `assert(...)` or `error(msg)` for unrecoverable states; return `nil, msg` for expected failures; do not swallow errors.
10. Functions: validate external (public) args early; internal helpers may assume sanitized input.
11. Exports: expose only via `return M`; avoid polluting `_G`.
12. Style: Stylua config (2-space, width 100, prefer double quotes, no call parens for simple calls) is authoritative.
13. Line length: Luacheck max_line_length=200; keep below 100 where reasonable.
14. Unused variables: prefix with `_` if intentionally unused; enable tooling silence.
15. Globals: only `vim` is permitted; no new globals. Use `vim.notify` for user-facing warnings.
16. Tests: structure with `describe`/`it` (plenary); keep fixtures minimal; avoid external network.
17. Side effects: keep module top-level pure (define functions); perform IO (e.g., `vim.system`) inside calls.
18. Diff apply logic must ensure patch safety; never write if unified diff parse fails.
19. Performance: cache picker/model lists; throttle streaming via config; avoid tight loops in UI updates.
20. Contribute: run lint + format + targeted test file before PR; CI also runs matrix Neovim versions.
