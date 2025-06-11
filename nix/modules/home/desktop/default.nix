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
      xkb-switch # for switching keyboard layouts
    ];

    # map WinKey(mod) short press to F1, used by qtile
    services.xcape = {
      enable = true;
      timeout = 300;
      mapExpression = {
        "Super_L" = "F1";
      };
    };

    # windows-switcher/application-lancher
    programs.rofi = {
      enable = true;
      cycle = true;
      terminal = config.home.sessionVariables.TERM;
      # more info at: https://davatorium.github.io/rofi/1.7.1/rofi.1/#configuration
      extraConfig = {
        # modes
        modi = "run,drun,ssh";
        display-drun = " Apps ";
        display-run = " Run ";
        display-ssh = " SSH ";
        sidebar-mode = true;

        max-history-size = 100;

        # searching
        matching = "fuzzy";
        sort = true;
        sorting-method = "fzf";

        # UI
        drun-display-format = "{icon} {name}";
        hide-scrollbar = true;
        cycle = true;

        # icons
        show-icons = true;
        icon-theme = "Papirus-dark";

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
        onChange = "${getExe pkgs.qtile-unwrapped} cmd-obj -o cmd -f reload_config";
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
