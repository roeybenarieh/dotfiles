{ pkgs, ... }:

{
  home.packages = with pkgs; [
    pkgs.neovim
    pkgs.ripgrep
    pkgs.nixpkgs-fmt
    pkgs.xclip
    pkgs.gcc
    pkgs.fd
  ];
  home.sessionVariables = { EDITOR = "nvim"; };
  home.shellAliases = { n = "nvim"; };
}
