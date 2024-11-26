local attempt_key_maps = function()
  local wk = require("which-key")
  wk.add({
    { "<leader>fs", group = "scratch files" },
    {
      "<leader>fsn",
      function()
        require("attempt").new_select()
      end,
      desc = "new scratch file",
    },
    {
      "<leader>fso",
      "<cmd> Telescope attempt <cr>",
      desc = "open scratch file",
    },
    {
      "<leader>fsr",
      function()
        require("attempt").rename_buf()
      end,
      desc = "rename scratch file",
    },
    {
      "<leader>fsd",
      function()
        require("attempt").delete_buf()
      end,
      desc = "delete scratch file",
    },
    {
      "<leader>fsN",
      function()
        require("attempt").new_input_ext()
      end,
      desc = "new named scratch file",
    },
  })
end
attempt_key_maps()

return {
  "m-demare/attempt.nvim",
  lazy = true,
  dependencies = {
    "nvim-lua/plenary.nvim",
    "telescope.nvim",
    "nvim-telescope/telescope-ui-select.nvim",
  },
  opts = {
    list_buffers = true, -- This will make them show on other pickers (like :Telescope buffers)
    ext_options = { "py", "lua", "js", "cpp", "c", "", "json", "json5", "yaml", "go", "txt" }, -- Options to choose from
  },
  config = function(_, opts)
    require("attempt").setup(opts)
    require("telescope").load_extension("attempt")
  end,
}
