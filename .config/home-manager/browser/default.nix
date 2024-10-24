{ pkgs, ... }:

{
  imports = [
    ./tor.nix
    ./chromium.nix
  ];
}

