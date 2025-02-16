{ config, pkgs, ... }:

{
  imports =
    [ ./ide ./source-control ./langueges ./netwoking.nix ./virtualization ];
  home.packages = with pkgs; [
    # debug programs
    ltrace
    strace

    # archive management
    zip
    unzip
  ];
}
