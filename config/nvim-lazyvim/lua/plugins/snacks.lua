-- Konfigurasi tampilan Snacks: dashboard dan file explorer.
return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          explorer = {
            hidden = true,
            ignored = true,
            layout = {
              layout = { position = "right" },
            },
          },
        },
      },
      dashboard = {
        preset = {
          header = [[
 █████ ███████████ █████ ██████████   █████ ██████████
░░███ ░░███░░░░░░█░░███ ░░███░░░░███ ░░███ ░░███░░░░░█
 ░███  ░███   █ ░  ░███  ░███   ░░███ ░███  ░███  █ ░ 
 ░███  ░███████    ░███  ░███    ░███ ░███  ░██████   
 ░███  ░███░░░█    ░███  ░███    ░███ ░███  ░███░░█   
 ░███  ░███  ░     ░███  ░███    ███  ░███  ░███ ░   █
 █████ █████       █████ ██████████   █████ ██████████
░░░░░ ░░░░░       ░░░░░ ░░░░░░░░░░   ░░░░░ ░░░░░░░░░░
]],
        },
      },
    },
  },
}
