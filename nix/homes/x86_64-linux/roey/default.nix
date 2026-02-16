{ lib, ... }:

with lib.extra;
{
  extra = {
    cli = enabled;
    desktop = disabled; # should be enabled according to NixOS desktop environment configuration
    entertainment = enabled;
    firefox = enabled;
    git = enabled;
    jetbrains = enabled;
    neovim = enabled;
    social = enabled;
    terminal = enabled;
    tmux = disabled;
    tor = enabled;
    vscode = enabled;
    windows = enabled;
    zsh = enabled;
    networking = enabled;
    containers = enabled;
    python = enabled;
    go = enabled;
    game-dev = enabled;
    office = enabled;
  };

  home = {
    username = "roey";
    homeDirectory = "/home/roey";
    stateVersion = "24.05";
  };
}
