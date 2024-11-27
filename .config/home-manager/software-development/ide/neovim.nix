{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    withPython3 = true;
    withNodeJs = true;
    # TODO: understand why this is working although it is not documented
    extraPackages = with pkgs; [
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
  };
  xdg.configFile."nvim" = {
    source = ../../../nvim;
    recursive = true;
  };
  home.shellAliases = { n = "nvim"; };
}
