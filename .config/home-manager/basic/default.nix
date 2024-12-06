{ pkgs, ... }:

{
  imports = [ ./fzf.nix ./zoxide.nix ./bat.nix ./eza.nix ];
  home.packages = with pkgs; [
    # file system
    tree
    baobab # disk usage GUI
    nautilus # file explorer

    # system diagnostic
    btop # like htop but better

    # networking related
    curl
    wget

    # text editing
    vim
    xclip # sharing system clipboard with terminal clipboard

    # file types
    unzip # using .zip files

    # utils
    tldr

    # fun
    neofetch
    cmatrix
    cowsay
  ];
  home.shellAliases = { c = "clear"; };
  # set nauilus as default folder explorer
  xdg.mimeApps.defaultApplications = {
    "inode/directory" = "nautilus";
  };
}
