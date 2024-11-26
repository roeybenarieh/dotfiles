return {
  "Wansmer/binary-swap.nvim",
  config = true,
  keys = {
    {
      "<leader>cbs",
      function()
        require("binary-swap").swap_operands()
      end,
      "switch operands(x>y=>y>x)",
    },
    {
      "<leader>cbS",
      function()
        require("binary-swap").swap_operands_with_operator()
      end,
      "switch operands & operator(x>y=>y<x)",
    },
  },
}
