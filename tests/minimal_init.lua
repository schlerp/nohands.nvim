-- Minimal Neovim init for plenary tests
-- Adjust runtimepath to include plugin root

vim.cmd("set runtimepath+=" .. vim.fn.getcwd())
-- Provide Snacks stub if absent

vim.cmd "enew"
if not pcall(require, "snacks") then
  package.preload["snacks"] = function()
    return {
      picker = {
        prompt = function(opts)
          -- Immediately invoke on_submit for first item in tests
          if opts and opts.on_submit and opts.items and opts.items[1] then
            opts.on_submit(opts.items[1])
          end
        end,
      },
    }
  end
end
