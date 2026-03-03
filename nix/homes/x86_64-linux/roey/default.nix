{ lib, ... }:

with lib.extra;
{
  extra = {
    cli = enabled;
    desktop = disabled; # should be enabled according to NixOS desktop environment configuration
    entertainment = enabled;
    firefox = enabled;
    git = enabled;
    social = enabled;
    terminal = enabled;
    tmux = disabled;
    tor = enabled;
    windows = enabled;
    zsh = enabled;
    networking = enabled;
    software-development = {
      containers = enabled;
      ide = {
        jetbrains = enabled;
        neovim = enabled;
        vscode = enabled;
      };
      languages = {
        go = enabled;
        python = enabled;
      };
    };
    game-dev = enabled;
    office = enabled;
    claude = enabled;
  };

  home = {
    username = "roey";
    homeDirectory = "/home/roey";
    stateVersion = "24.05";
  };
}
