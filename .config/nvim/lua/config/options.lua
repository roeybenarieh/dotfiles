-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- make neovim use both the 'selection' clipboard ('unnamed') and the 'normal' clipboard the rest of the OS is using ('unnamedplus')
-- this configuration only matters in linux OSes, in windows both clipboards are already combained as part of the OS
-- https://stackoverflow.com/questions/30691466/what-is-difference-between-vims-clipboard-unnamed-and-unnamedplus-settings
vim.cmd("set clipboard^=unnamed,unnamedplus")
