return {
  -- annotation generator
  "danymat/neogen",
  keys = {
    {
      "<leader>cds",
      function()
        require("neogen").generate({})
      end,
      desc = "Create Docstring",
    },
  },
  opts = {
    enabled = true,
    languages = {
      python = {
        template = {
          annotation_convention = "reST",
        },
      },
    },
  },
}
