{ lib, osConfig ? { }, ... }:

with lib.extra;
{
  extra = {
    cli = enabled;
    desktop.enable = osConfig.services.xserver.windowManager.qtile.enable or false;
    entertainment = enabled;
    browser = {
      default_browser = "chromium";
      chromium = enabled;
    };
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
  # options related to the fact that my stateVersion is old :-(
  gtk.gtk4.theme = null;
  programs.git.signing.format = null;
}
