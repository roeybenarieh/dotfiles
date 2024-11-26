return {
  "wintermute-cell/gitignore.nvim",
  dependencies = "nvim-telescope/telescope.nvim", -- optional: for multi-select
  keys = {
    {
      "<leader>gi",
      function()
        local cur_directory = vim.fn.getcwd()
        require("gitignore").generate(cur_directory)
      end,
      desc = "Create gitignore file",
    },
  },
}
