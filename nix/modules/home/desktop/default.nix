{ pkgs, namespace, lib, config, inputs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop;
  reload_qtile_command = "${getExe pkgs.qtile-unwrapped} cmd-obj -o cmd -f reload_config";
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

    # notification daemon used by qtile
    services.dunst = {
      enable = true;
      settings.global = {
        frame_width = 0;
        gap_size = 5;
      };
    };

    # clipboard manager
    services.clipmenu.enable = true;

    xdg.configFile = {
      "qtile" = {
        source = ./qtile;
        onChange = reload_qtile_command;
      };
      "qtile-injection/config.json" = {
        text = builtins.toJSON rec {
          browser = config.home.sessionVariables.BROWSER;
          wallpaper = "${inputs.assets}/wallpaper.png";
          terminal = config.home.sessionVariables.TERMINAL;
          font = config.stylix.fonts.monospace.name;
          screenshot_dir = "${config.home.homeDirectory}/Pictures/Screenshots";
          network_manager = "${terminal} -e nmtui";
          task_manager = "${terminal} -e ${config.home.shellAliases.htop}";
          audio_visualizer = "${terminal} -e ${getExe pkgs.cava}";
          auidio_controller = getExe pkgs.pavucontrol;
        };
        onChange = reload_qtile_command;
      };
      # "rofi" = {
      #   source = ./rofi;
      #   recursive = true;
      # };
      "picom" = {
        source = ./picom;
        onChange = "${getExe pkgs.killall} picom || true; ${getExe pkgs.picom} -b";
      };
    };
  };
}
