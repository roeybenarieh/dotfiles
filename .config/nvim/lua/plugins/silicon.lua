return {
  "michaelrommel/nvim-silicon",
  -- lazy = true,
  -- cmd = "Silicon",
  opts = {
    font = "FreeSans",
    theme = "TwoDark",
    line_pad = 5,
  },
  keys = {
    {
      mode = { "n" },
      "<leader>csa",
      "<CMD>Silicon<CR>",
      desc = "buffer snapshot",
    },
    {
      mode = { "v" }, -- 's' stands for "select". this is when text is selected in visual mode
      "<leader>cs",
      ":Silicon <CR>",
      desc = "text selection snapshot",
    },
  },
}
