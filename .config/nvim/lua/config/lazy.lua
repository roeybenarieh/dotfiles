local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  -- bootstrap lazy.nvim
  -- stylua: ignore
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(vim.env.LAZY or lazypath)

require("lazy").setup({
  spec = {
    -- add LazyVim and import its plugins
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },

    -- ui staff
    { import = "lazyvim.plugins.extras.ui.edgy" }, -- predefined windows layout

    -- import any extras modules here
    { import = "lazyvim.plugins.extras.coding.copilot" }, -- AI autocompletion
    { import = "lazyvim.plugins.extras.coding.copilot-chat" }, -- AI chat
    { import = "lazyvim.plugins.extras.coding.yanky" }, -- imporoved yank and put functionalities
    { import = "lazyvim.plugins.extras.coding.mini-surround" }, -- surround text with stuff
    { import = "lazyvim.plugins.extras.coding.mini-comment" }, -- create code comments
    { import = "lazyvim.plugins.extras.editor.aerial" }, -- Neovim plugin for a code outline window
    { import = "lazyvim.plugins.extras.editor.leap" }, -- jump to words in the document
    { import = "lazyvim.plugins.extras.editor.navic" }, -- Simple winbar/statusline plugin that shows your current code context
    { import = "lazyvim.plugins.extras.editor.mini-files" }, -- Navigate and manipulate file system
    { import = "lazyvim.plugins.extras.editor.inc-rename" },

    -- dap
    { import = "lazyvim.plugins.extras.dap.core" }, -- dap capabilities

    -- formatting
    { import = "lazyvim.plugins.extras.formatting.prettier" }, -- Prettier formmatter

    --linting
    { import = "lazyvim.plugins.extras.linting.eslint" }, -- javascript static linting

    -- docstrings
    { import = "lazyvim.plugins.extras.coding.neogen" },

    -- highliting
    -- { import = "lazyvim.plugins.extras.lang.python-semshi" }, -- syntax highliting for python
    { import = "lazyvim.plugins.extras.util.mini-hipatterns" }, -- common highliting solutions

    -- none ls
    { import = "lazyvim.plugins.extras.lsp.none-ls" },

    --testing framework (testing runners are needed for each language)
    { import = "lazyvim.plugins.extras.test.core" },

    --utils
    { import = "lazyvim.plugins.extras.util.dot" }, -- hyperland parser (https://github.com/hyprwm/Hyprland)
    { import = "lazyvim.plugins.extras.util.project" }, -- The superior project management solution for neovim.
    { import = "lazyvim.plugins.extras.editor.telescope" }, -- telescope fzf integration and more

    -- languages
    { import = "lazyvim.plugins.extras.lang.python" },
    { import = "lazyvim.plugins.extras.lang.go" },
    { import = "lazyvim.plugins.extras.lang.java" },
    { import = "lazyvim.plugins.extras.lang.nix" },
    { import = "lazyvim.plugins.extras.lang.docker" },
    { import = "lazyvim.plugins.extras.lang.helm" },
    { import = "lazyvim.plugins.extras.lang.json" },
    { import = "lazyvim.plugins.extras.lang.yaml" },
    { import = "lazyvim.plugins.extras.lang.markdown" },
    { import = "lazyvim.plugins.extras.lang.sql" },
    { import = "lazyvim.plugins.extras.lang.toml" },

    { import = "lazyvim.plugins.extras.lang.git" },
    { import = "lazyvim.plugins.extras.lang.rust" },
    { import = "lazyvim.plugins.extras.lang.tailwind" },
    { import = "lazyvim.plugins.extras.lang.terraform" },
    { import = "lazyvim.plugins.extras.lang.typescript" },
    { import = "lazyvim.plugins.extras.dap.nlua" },

    -- import/override with your plugins
    { import = "plugins" },
  },
  defaults = {
    -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
    -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
    lazy = false,
    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    version = false, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
  },
  install = { colorscheme = { "tokyonight", "habamax" } },
  checker = { enabled = true }, -- automatically check for plugin updates
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        "gzip",
        -- "matchit",
        -- "matchparen",
        -- "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
