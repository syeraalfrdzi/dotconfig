return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    opts = {
      open_mapping = [[<C-\>]],
      direction = "horizontal",
      size = function(term)
        if term.direction == "vertical" then
          return math.floor(vim.o.columns * 0.4)
        end
        return 15
      end,
      start_in_insert = true,
      terminal_mappings = true,
      persist_size = true,
      close_on_exit = true,
      float_opts = { border = "rounded" },
    },
    config = function(_, opts)
      require("toggleterm").setup(opts)

      local commands = {
        ToggleTermFloat = "float",
        ToggleTermHorizontal = "horizontal",
        ToggleTermVertical = "vertical",
      }
      for name, direction in pairs(commands) do
        vim.api.nvim_create_user_command(name, function()
          local term = require("toggleterm.terminal").get_or_create_term(1)
          -- Keep the shell session when switching between window layouts.
          if term:is_open() and term.direction ~= direction then
            term:close()
          end
          term:toggle(nil, direction)
        end, { desc = "Toggle terminal (" .. direction .. ")" })
      end
    end,
  },
}
