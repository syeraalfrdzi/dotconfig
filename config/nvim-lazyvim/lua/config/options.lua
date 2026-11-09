-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.background = "dark"
vim.opt.number = true
vim.opt.relativenumber = false

-- Use the workspace TypeScript service for Next.js and React development.
vim.g.lazyvim_ts_lsp = "vtsls"
