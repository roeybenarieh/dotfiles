return {
  {
    "rcarriga/nvim-dap-ui",
    opts = {
      layouts = {
        {
          elements = {
            {
              id = "scopes", -- variables values and their scope
              size = 0.25,
            },
            {
              id = "watches", -- for constant expressions evaluation
              size = 0.25,
            },
            {
              id = "breakpoints", -- breakpoints list
              size = 0.25,
            },
            {
              id = "stacks", -- call stack
              size = 0.25,
            },
          },
          position = "right",
          size = 40,
        },
        {
          elements = {
            -- {
            --   id = "repl",
            --   size = 0.5,
            -- },
            {
              id = "console",
              size = 1,
            },
          },
          position = "bottom",
          size = 10,
        },
      },
    },
    -- override lavyvim's config
    -- for more information on the events dap has, see:
    -- the possible events: https://microsoft.github.io/debug-adapter-protocol/specification#Events_Exited
    -- the way to use them: https://github.com/mfussenegger/nvim-dap/blob/master/doc/dap.txt#L1182
    config = function(_, opts)
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup(opts)
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open({})
      end
      -- lazy.nvim code I commented:
      -- dap.listeners.before.event_terminated["dapui_config"] = function()
      --   dapui.close({})
      -- end
      -- dap.listeners.before.event_exited["dapui_config"] = function()
      --   dapui.close({})
      -- end
    end,
  },
}
