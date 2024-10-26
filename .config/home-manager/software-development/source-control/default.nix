{ config, pkgs, lib, ... }:

{
  # install git clients
  imports = [ ./git-tui.nix ./git-ui.nix ];

  # install git itself
  programs.git = { enable = true; };
  # set the git config file
  home.file = {
    # TODO: change the path
    "${config.home.homeDirectory}/.config/git/config".source =
      lib.mkForce ../../../../.config/git/config;
  };
}
