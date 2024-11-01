{ pkgs, ... }:

{
  imports = [ ./fzf.nix ./zoxide.nix ./bat.nix ./eza.nix ];
  home.packages = with pkgs; [
    # file system
    tree
    baobab # disk usage GUI

    # system diagnostic
    btop # like htop but better

    # networking related
    curl
    wget

    # text editing
    vim

    # utils
    tldr

    # fun
    neofetch
    cmatrix
    cowsay
  ];
  home.shellAliases = { c = "clear"; };
}
