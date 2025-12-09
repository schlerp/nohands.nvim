-- Minimal Neovim init for plenary tests
-- Adjust runtimepath to include plugin root

vim.cmd("set runtimepath+=" .. vim.fn.getcwd())
vim.cmd "enew"

-- Simple vim.ui.select-style helper for tests
vim.ui.select = function(items, _opts, on_choice)
  if items and items[1] and on_choice then
    on_choice(items[1])
  elseif on_choice then
    on_choice(nil)
  end
end
