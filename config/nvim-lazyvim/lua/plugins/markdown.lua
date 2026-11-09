-- Konfigurasi markdown: matikan lint DAN spell checking untuk markdown.
-- Markdown Preview, render-markdown, marksman, dan markdown-toc tetap aktif.

-- Matikan spell checking untuk markdown.
-- LazyVim menyalakan `spell` pada filetype markdown lewat autocmd `lazyvim_wrap_spell`
-- (di lazyvim/config/autocmds.lua), yang menggambar garis merah squiggly di bawah
-- kata yang tidak ada di kamus "en". Spell untuk text/gitcommit tetap aktif.
--
-- Autocmd LazyVim itu dibuat setelah plugin file ini dimuat, jadi tidak bisa kita
-- hapus di sini. Sebagai gantinya pakai BufWinEnter, yang selalu berjalan SETELAH
-- FileType: matikan lagi spell-nya kalau buffer yang masuk window adalah markdown.
vim.api.nvim_create_augroup("disable_markdown_spell", { clear = true })

vim.api.nvim_create_autocmd("BufWinEnter", {
  group = "disable_markdown_spell",
  callback = function(args)
    if vim.api.nvim_get_option_value("filetype", { buf = args.buf }) == "markdown" then
      vim.opt_local.spell = false
    end
  end,
})

return {
  -- Hapus linter markdown dari nvim-lint
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.markdown = {}
      opts.linters_by_ft["markdown.mdx"] = {}
    end,
  },

  -- Hapus formatter markdownlint-cli2 dari conform.nvim
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      for _, ft in ipairs({ "markdown", "markdown.mdx" }) do
        local formatters = opts.formatters_by_ft and opts.formatters_by_ft[ft]
        if formatters then
          opts.formatters_by_ft[ft] = vim.tbl_filter(function(f)
            return f ~= "markdownlint-cli2"
          end, formatters)
        end
      end
    end,
  },

  -- Jangan install markdownlint-cli2 lewat mason
  {
    "mason-org/mason.nvim",
    optional = true,
    opts = function(_, opts)
      opts.ensure_installed = vim.tbl_filter(function(pkg)
        return pkg ~= "markdownlint-cli2"
      end, opts.ensure_installed or {})
    end,
  },
}
