return {
    -- buffer history
    "jiaoshijie/undotree",
    dependencies = "nvim-lua/plenary.nvim",
    config = true,
    keys = { -- load the plugin only when using it's keybinding:
        {
            "<leader>u",
            function()
                require('undotree').toggle()
            end,
            "toogle undotree"
        },
    },
    opts = {
        window = {
            winblend = 0,
            height = 0,
            width = 2,
        }
    }
}
