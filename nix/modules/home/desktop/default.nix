{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop;
in
{
  options.${namespace}.desktop = with types; {
    enable = mkBoolOpt false "Whether or not to enable desktop.";
  };

  config = mkIf cfg.enable {
    # x11 compositor with animations & rounded-corners
    services.picom = {
      enable = true;
      backend = "glx";
      extraArgs = [
        # "--experimental-backends" # for glx backend and reounded corners
        "-b" # run the backend
      ];
    };
    home.packages = with pkgs; [
      pamixer # control volume
      playerctl # control playing
      brightnessctl # control brightness
      flameshot # screenshots
      xorg.setxkbmap # for changing keyboard layout
      btop # for viewing system resources
      arandr # for editing monitors layout(positioning them relative to each other)
      alttab # window switcher
      rofi-bluetooth
      bluez-experimental
    ];

    # windows-switcher/application-lancher
    programs.rofi = {
      enable = true;
      cycle = true;
      extraConfig = {
        show-icons = true;
        kb-cancel = "Escape";
        scroll-method = 0;
        modi = "drun,ssh";
        sort = true;
      };
      plugins = with pkgs; [
        rofi-bluetooth
      ];
    };

    # clipboard manager
    services.clipmenu.enable = true;

    xdg.configFile = {
      "qtile" = {
        source = ./qtile;
        recursive = true;
      };
      # "rofi" = {
      #   source = ./rofi;
      #   recursive = true;
      # };
      "picom" = {
        source = ./picom;
        recursive = true;
      };
    };
  };
}
