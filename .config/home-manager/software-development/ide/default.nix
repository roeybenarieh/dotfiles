{ config, pkgs, pkgs-stable, ... }:

{
  imports = [ ./neovim.nix ];
  home.packages = with pkgs; [
    vscode
  ];
}
