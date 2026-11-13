{ lib, config, osConfig ? { }, ... }:

with lib.extra;
{
  extra = {
    cli = enabled;
    git = enabled;
    zsh = enabled;
    software-development.ide.neovim = enabled;
  };

  home = {
    username = "remote";
    homeDirectory = "/home/remote";
    stateVersion = "24.05";
  };
  # options related to the fact that my stateVersion is old :-(
  programs = {
    git.signing.format = null;
    neovim.withRuby = false;
    firefox.configPath = "${config.xdg.configHome}/mozilla/firefox";
  };
}
