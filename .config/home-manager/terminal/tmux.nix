{ config, pkgs, lib, ... }:

{
  programs.tmux = { enable = true; };
  home.file = lib.mkForce {
    qtile_configs = {
      source = ../../tmux;
      target = ".config/tmux"; # path relative to $HOME
    };
  };
}
