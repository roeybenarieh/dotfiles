{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gitbutler # doesnt work
    gitnuro
  ];
}
