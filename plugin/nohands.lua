-- Runtime entry for nohands.nvim
-- This file is loaded automatically by Neovim when installed via a plugin manager.
if vim.g.loaded_nohands then
  return
end
vim.g.loaded_nohands = 1 -- luacheck: ignore

-- Call setup with no opts; user can later invoke require('nohands').setup({...}) in their config.
pcall(function()
  require("nohands").setup()
end)
