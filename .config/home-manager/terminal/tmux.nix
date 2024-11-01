{ config, pkgs, ... }:

{
  programs.tmux = { enable = true; };
  # home.file = {
  #   # TODO: change the path
  #   "${config.home.homeDirectory}/.config/tmux/config".source =
  #     lib.mkForce ../../../../.config/git/config;
  # };
}
