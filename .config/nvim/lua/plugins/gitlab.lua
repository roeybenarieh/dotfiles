-- registering the gitlab keymap prefix
local wk = require("which-key")
wk.add({
  { "<leader>gl", group = "MR gitlab handler" },
})

return {
  "harrisoncramer/gitlab.nvim",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-lua/plenary.nvim",
    "sindrets/diffview.nvim",
    "stevearc/dressing.nvim", -- Better UI for pickers, not required.
    enabled = true,
  },
  lazy = true,
  build = function()
    require("gitlab.server").build(true)
  end, -- Builds the Go binary
  config = function()
    require("gitlab").setup()
  end,
  keys = {
    {
      "<leader>glr",
      function()
        require("gitlab").review()
      end,
      desc = "open MR review",
    },
    {
      "<leader>gls",
      function()
        require("gitlab").summary()
      end,
      desc = "open MR title and description",
    },
    {
      "<leader>glA",
      function()
        require("gitlab").approve()
      end,
      desc = "approve MR",
    },
    {
      "<leader>glR",
      function()
        require("gitlab").revoke()
      end,
      desc = "revoke MR",
    },
    {
      "<leader>glc",
      function()
        require("gitlab").comment()
      end,
      desc = "create a comment on MR",
    },
    {
      "<leader>glmc", -- in docs should be the same as comment
      function()
        require("gitlab").create_multiline_comment()
      end,
      desc = "create a multiline comment on a MR",
    },
    {
      "<leader>glC",
      function()
        require("gitlab").create_comment_suggestion()
      end,
      desc = "create comment suggestion on a MR",
    },
    {
      "<leader>glm",
      function()
        require("gitlab").move_to_discussion_tree_from_diagnostic()
      end,
      desc = "move to discussion tree from MR diagnostic",
    },
    {
      "<leader>gln",
      function()
        require("gitlab").create_note()
      end,
      desc = "create a note on a MR",
    },
    {
      "<leader>gld",
      function()
        require("gitlab").toggle_discussions()
      end,
      desc = "toggle MR discussions",
    },
    {
      "<leader>glaa",
      function()
        require("gitlab").add_assignee()
      end,
      desc = "add assignee to MR",
    },
    {
      "<leader>glda",
      function()
        require("gitlab").delete_assignee()
      end,
      desc = "delete assignee from MR",
    },
    {
      "<leader>glar",
      function()
        require("gitlab").add_reviewer()
      end,
      desc = "add reviewer to MR",
    },
    {
      "<leader>gldr",
      function()
        require("gitlab").approve()
      end,
      desc = "delete reviewer from MR",
    },
    {
      "<leader>glp",
      function()
        require("gitlab").pipeline()
      end,
      desc = "open MR pipeline",
    },
    {
      "<leader>glo",
      function()
        require("gitlab").open_in_browser()
      end,
      desc = "open MR in browser",
    },
  },
}
