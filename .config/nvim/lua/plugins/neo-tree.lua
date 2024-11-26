return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    filesystem = {
      -- use file.mini to delete files
      commands = {
        delete = function()
          -- disabling default delete command
        end,

        delete_visual = function()
          -- disabling visual deleting
        end,
      },
    },
  },
}
