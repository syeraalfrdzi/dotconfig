return {
  -- Go Live: preview HTML/CSS/JS di browser dan reload saat file disimpan.
  {
    "barrettruth/live-server.nvim",
    cmd = { "LiveServerStart", "LiveServerStop", "LiveServerToggle" },
    init = function()
      vim.g.live_server = {
        port = 5500,
        browser = true,
      }
    end,
    keys = {
      { "<leader>cG", "<cmd>LiveServerToggle<cr>", desc = "Go Live (toggle)" },
      { "<leader>cX", "<cmd>LiveServerStop<cr>", desc = "Stop Live Server" },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        html = {},
        cssls = {},
        emmet_language_server = {
          filetypes = { "html", "css", "scss", "less", "javascriptreact", "typescriptreact" },
        },
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "vtsls",
        "tailwindcss-language-server",
        "json-lsp",
        "eslint-lsp",
        "html-lsp",
        "css-lsp",
        "emmet-language-server",
      },
    },
  },
}
