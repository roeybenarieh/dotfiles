return {
  "theHamsta/nvim-dap-virtual-text",
  -- for some reason this fucks up persistent-breakpoints.nvim
  -- lazy = true,
  opts = {
    all_frames = true, -- shows virtual text for all frames that are in your file
  },
}
