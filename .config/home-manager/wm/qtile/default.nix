{ pkgs, ... }:
{
  home.packages = with pkgs; [
    pamixer # control volume
    playerctl # control playing
    brightnessctl # control brightness
    flameshot # screenshots
    rofi # windows-switcher/application-lancher
    xorg.setxkbmap # for changing keyboard layout
    btop # for viewing system resources
    arandr # for editing monitors layout(positioning them relative to each other)
    alttab # window switcher
  ];
  # clipboard manager
  services.clipmenu.enable = true;

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
