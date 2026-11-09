-- Use a directory argument as the working directory without opening its file tree.
if vim.fn.argc(-1) == 1 then
  local directory = vim.fn.argv(0)
  if vim.fn.isdirectory(directory) == 1 then
    vim.cmd.cd({ args = { directory } })
    vim.cmd("argdelete *")
    vim.api.nvim_buf_set_name(0, "")
  end
end

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
