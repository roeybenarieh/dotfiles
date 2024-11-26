--[[
IMPORTANT for future development:
-nvim-dap must be loaded before persistent-breakpoints.nvim, otherwise there are errors.
-persistent-breakpoints.nvim must be loaded before a file is opned, otherwise breakpoints are not restored.
-if restoring an nvim session (using persistence.nvim) in the UI we see an open buffer, but the 'BufRead.*' event is not triggered, so breakpoints are not restored.
currently since the breakpoints are anyway necessery only after LSP is attached, we use that event to load the breakpoints(which works even if restoring session).
]]
return {
  {
    "mfussenegger/nvim-dap",

    dependencies = {
      "Weissle/persistent-breakpoints.nvim",
    },
  },
  {
    "Weissle/persistent-breakpoints.nvim",
    event = "LspAttach",
    opts = {
      load_breakpoints_event = "BufReadPost",
    },
    keys = {
      {
        "<leader>db",
        function()
          require("persistent-breakpoints.api").toggle_breakpoint()
        end,
        silent = true,
        desc = "Toggle Breakpoint",
        remap = false, -- override default mapping
      },
      {
        "<leader>dB",
        function()
          require("persistent-breakpoints.api").set_conditional_breakpoint()
        end,
        silent = true,
        desc = "Breakpoint Condition",
        remap = false,
      },
      {
        "<leader>dbc",
        function()
          require("persistent-breakpoints.api").clear_all_breakpoints()
        end,
        silent = true,
        desc = "Clear Breakpoints",
        remap = false,
      },
    },
  },
}
