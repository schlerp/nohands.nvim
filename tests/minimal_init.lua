-- Minimal Neovim init for plenary tests
-- Adjust runtimepath to include plugin root

vim.cmd("set runtimepath+=" .. vim.fn.getcwd())
-- Provide Snacks stub if absent

vim.cmd "enew"
if not pcall(require, "snacks") then
  package.preload["snacks"] = function()
    return {
      picker = {
        -- Simple vim.ui.select-style helper for tests
        ---@param items any[]
        ---@param _opts table|nil
        ---@param on_choice fun(item:any|nil)
        select = function(items, _opts, on_choice)
          if items and items[1] and on_choice then
            on_choice(items[1])
          elseif on_choice then
            on_choice(nil)
          end
        end,
      },
    }
  end
end
