{ pkgs, ... }:
{
  home.packages = with pkgs; [
    pamixer # control volume
    playerctl # control playing
    brightnessctl # control brightness
    flameshot # screenshots
    betterlockscreen # logout user
    rofi # windows-switcher/application-lancher
  ];
  xdg.configFile = {
    "qtile" = {
      source = ../../../qtile;
      recursive = true;
    };
    "rofi" = {
      source = ../../../rofi;
      recursive = true;
    };
  };
}
