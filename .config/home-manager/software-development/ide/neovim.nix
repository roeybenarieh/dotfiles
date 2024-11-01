{ pkgs, ... }:

{
  home.packages = with pkgs; [ pkgs.neovim pkgs.ripgrep pkgs.nixpkgs-fmt pkgs.xclip pkgs.gcc ];
  home.sessionVariables = { EDITOR = "nvim"; };
  home.shellAliases = { n = "nvim"; };
}
