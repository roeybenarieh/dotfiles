{ pkgs, ... }:
{
  home.packages = with pkgs; [
    pamixer # control volume
    playerctl # control playing
    brightnessctl # control brightness
    flameshot # screenshots
    betterlockscreen # logout user
  ];
  xdg.configFile."qtile" = {
    source = ../../../qtile;
    recursive = true;
  };
}
