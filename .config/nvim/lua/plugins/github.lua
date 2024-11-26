local github_key_maps = function()
  local wk = require("which-key")
  wk.add({
    { "<leader>gh", group = "Github" },

    { "leader>ghc", group = "Github Commits" },
    { "<leader>ghcc>", "<cmd>GHCloseCommit<cr>", desc = "Close" },
    { "<leader>ghce", "<cmd>GHExpandCommit<cr>", desc = "Expand" },
    { "<leader>ghco", "<cmd>GHOpenToCommit<cr>", desc = "Open To" },
    { "<leader>ghcp", "<cmd>GHPopOutCommit<cr>", desc = "Pop Out" },
    { "<leader>ghcz", "<cmd>GHCollapseCommit<cr>", desc = "Collapse" },

    { "leader>ghi", group = "Github Issues" },
    { "<leader>ghip", "<cmd>GHPreviewIssue<cr>", desc = "Preview" },

    { "leader>ghl", group = "Github Litee" },
    { "<leader>ghlt", "<cmd>LTPanel<cr>", desc = "Toggle Panel" },

    { "leader>ghr", group = "Github Review" },
    { "<leader>ghrb", "<cmd>GHStartReview<cr>", desc = "Begin" },
    { "<leader>ghrc", "<cmd>GHCloseReview<cr>", desc = "Close" },
    { "<leader>ghrd", "<cmd>GHDeleteReview<cr>", desc = "Delete" },
    { "<leader>ghre", "<cmd>GHExpandReview<cr>", desc = "Expand" },
    { "<leader>ghrs", "<cmd>GHSubmitReview<cr>", desc = "Submit" },
    { "<leader>ghrz", "<cmd>GHCollapseReview<cr>", desc = "Collapse" },

    { "leader>ghp", group = "Github Pull Request" },
    { "<leader>ghpc", "<cmd>GHClosePR<cr>", desc = "Close" },
    { "<leader>ghpd", "<cmd>GHPRDetails<cr>", desc = "Details" },
    { "<leader>ghpd", "<cmd>GHExpandPR<cr>", desc = "Expand" },
    { "<leader>ghpo", "<cmd>GHOpenPR<cr>", desc = "Open" },
    { "<leader>ghpp", "<cmd>GHPopOutPR<cr>", desc = "PopOut" },
    { "<leader>ghpr", "<cmd>GHRefreshPR<cr>", desc = "Refresh" },
    { "<leader>ghpt", "<cmd>GHOpenToPR<cr>", desc = "Open To" },
    { "<leader>ghpz", "<cmd>GHCollapsePR<cr>", desc = "Collapse" },

    { "leader>ght", group = "Github Threads" },
    { "<leader>ghtc", "<cmd>GHCreateThread<cr>", desc = "Create" },
    { "<leader>ghtn", "<cmd>GHNextThread<cr>", desc = "Next" },
    { "<leader>ghtt", "<cmd>GHToggleThread<cr>", desc = "Toggle" },
  })

  wk.register({
    g = {
      h = {
        name = "+Github",
        c = {
          name = "+Commits",
        },
        i = {
          name = "+Issues",
          p = { "<cmd>GHPreviewIssue<cr>", "Preview" },
        },
        l = {
          name = "+Litee",
          t = { "<cmd>LTPanel<cr>", "Toggle Panel" },
        },
        r = {
          name = "+Review",
          b = { "<cmd>GHStartReview<cr>", "Begin" },
          c = { "<cmd>GHCloseReview<cr>", "Close" },
          d = { "<cmd>GHDeleteReview<cr>", "Delete" },
          e = { "<cmd>GHExpandReview<cr>", "Expand" },
          s = { "<cmd>GHSubmitReview<cr>", "Submit" },
          z = { "<cmd>GHCollapseReview<cr>", "Collapse" },
        },
        p = {
          name = "+Pull Request",
          c = { "<cmd>GHClosePR<cr>", "Close" },
          d = { "<cmd>GHPRDetails<cr>", "Details" },
          e = { "<cmd>GHExpandPR<cr>", "Expand" },
          o = { "<cmd>GHOpenPR<cr>", "Open" },
          p = { "<cmd>GHPopOutPR<cr>", "PopOut" },
          r = { "<cmd>GHRefreshPR<cr>", "Refresh" },
          t = { "<cmd>GHOpenToPR<cr>", "Open To" },
          z = { "<cmd>GHCollapsePR<cr>", "Collapse" },
        },
        t = {
          name = "+Threads",
          c = { "<cmd>GHCreateThread<cr>", "Create" },
          n = { "<cmd>GHNextThread<cr>", "Next" },
          t = { "<cmd>GHToggleThread<cr>", "Toggle" },
        },
      },
    },
  }, { prefix = "<leader>" })
end

return {
  "ldelossa/gh.nvim",
  dependencies = {
    {
      "ldelossa/litee.nvim",
      config = function()
        require("litee.lib").setup()
      end,
    },
  },
  lazy = true,
  config = function()
    require("litee.gh").setup()
    github_key_maps()
  end,
}
