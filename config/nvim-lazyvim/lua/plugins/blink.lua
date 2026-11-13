return {
  {
    "saghen/blink.cmp",
    opts = function(_, opts)
      -- Urutan <Tab>:
      -- 1. terima ghost text Copilot kalau sedang tampil (mode ai_cmp = false)
      -- 2. terima item yang dipilih di menu (termasuk saran Copilot di mode ai_cmp = true)
      -- 3. lompat ke placeholder snippet berikutnya
      -- 4. kalau tidak ada semuanya: Tab biasa
      -- <CR> dan <C-y> tetap bisa dipakai (preset "enter" bawaan LazyVim).
      opts.keymap = opts.keymap or {}
      opts.keymap["<Tab>"] = {
        LazyVim.cmp.map({ "ai_accept" }),
        "select_and_accept",
        "snippet_forward",
        "fallback",
      }
    end,
  },
}
