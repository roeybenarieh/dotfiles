{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    withPython3 = true;
    withNodeJs = true;
  };
  xdg.configFile."nvim" = {
    source = ../../../nvim;
    recursive = true;
  };
  home.packages = with pkgs; [
    ripgrep
    nixpkgs-fmt
    xclip
    gcc
    fd

    # python related
    pyright
    python311Packages.debugpy
    python311Packages.ruff
  ];
  home.shellAliases = { n = "nvim"; };
}
