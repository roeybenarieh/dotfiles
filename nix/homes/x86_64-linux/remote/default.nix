{ lib, config, osConfig ? { }, ... }:

with lib.extra;
{
  extra = {
    cli = enabled;
    git = enabled;
    zsh = enabled;
    software-development.ide.neovim = enabled;
    # AI agents, same set as the laptop's roey profile (minus desktop-only pieces).
    claude = {
      enable = true;
      statusLine = enabled;
    };
    codex = enabled;
    opencode = {
      enable = true;
      server.enable = osConfig.extra.opencode-serve.enable or false;
    };
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
