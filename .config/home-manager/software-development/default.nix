{ config, pkgs, ... }:

{
  imports =
    [ ./ide ./source-control ./langueges ./netwoking.nix ./virtualization ];
}
