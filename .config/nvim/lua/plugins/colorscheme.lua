return {
  { "ellisonleao/gruvbox.nvim", lazy = true },
  -- vscode like theme
  { "Mofiqul/vscode.nvim", lazy = true },
  -- IntelliJ like theme
  { "briones-gabriel/darcula-solid.nvim", dependencies = "rktjmp/lush.nvim", lazy = true },
  -- catppuccino theme
  { "catppuccin/nvim", lazy = true },
  -- github theme
  { "projekt0n/github-nvim-theme", lazy = true },
  -- onedark theme
  { "navarasu/onedark.nvim", lazy = true },

  -- Configure LazyVim to load gruvbox
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox",
    },
  },
}
