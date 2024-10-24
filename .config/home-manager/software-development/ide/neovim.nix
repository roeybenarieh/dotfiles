{ pkgs, ... }:

{
  home.packages = with pkgs; [
    pkgs.neovim
    pkgs.ripgrep
    pkgs.nixpkgs-fmt
  ];
  home.sessionVariables = {
    EDITOR = "nvim";
  };
}
