return {
  {
    "vyfor/cord.nvim",
    lazy = false,
    opts = {
      enabled = true,
      advanced = {
        discord = {
          reconnect = {
            enabled = true,
            initial = true,
            interval = 5000,
          },
        },
      },
    },
  },
}
