local telescope_dap_key_maps = function()
  local wk = require("which-key")
  wk.add({
    { "<leader>dL", group = "list dap statistics" },
    {
      "<leader>dLC",
      "<cmd> Telescope dap commands <CR>",
      desc = "list debug commands",
    },
    {
      "<leader>dLc",
      "<cmd> Telescope dap configurations<CR>",
      desc = "list debug configurations",
    },
    {
      "<leader>dLb",
      "<cmd> Telescope dap list_breakpoints<CR>",
      desc = "list debug breakpoints",
    },
    {
      "<leader>dLv",
      "<cmd> Telescope dap variables<CR>",
      desc = "list debug variables",
    },
    {
      "<leader>dLf",
      "<cmd> Telescope dap frames<CR>",
      desc = "list debug frames",
    },
  })
end
telescope_dap_key_maps()

return {
  "nvim-telescope/telescope-dap.nvim",
  lazy = true,
  dependencies = {
    "telescope.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  -- keys = {
  --   "<leader>dLC",
  -- },
}
