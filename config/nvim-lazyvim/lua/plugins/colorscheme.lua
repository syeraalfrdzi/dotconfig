return {
  {
    "ellisonleao/gruvbox.nvim",
    -- Rilis 2.0.0 (2023) belum punya highlight Snacks picker/explorer,
    -- jadi ikuti commit terbaru di branch main.
    version = false,
    lazy = false,
    priority = 1000,
    opts = {},
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox",
    },
  },
}
