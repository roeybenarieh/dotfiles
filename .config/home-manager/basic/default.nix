{ pkgs, ... }:

{
  imports = [ ./fzf.nix ./zoxide.nix ./bat.nix ];
  home.packages = with pkgs; [
    # file system
    tree
    baobab # disk usage GUI

    # system diagnostic
    btop # like htop but better

    # networking related
    curl
    wget

    # fun
    cmatrix
    cowsay
  ];
}
