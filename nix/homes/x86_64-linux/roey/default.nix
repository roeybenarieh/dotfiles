{ lib, ... }:

with lib.extra;
{
  extra = {
    cli = enabled;
    desktop = enabled;
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
    services = enabled;
  };

  home = {
    username = "roey";
    homeDirectory = "/home/roey";
    stateVersion = "24.05";
  };
}
