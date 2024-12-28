{ pkgs, ... }:
{
  home.packages = with pkgs;[
    krita # GUI paint app
  ];
}
