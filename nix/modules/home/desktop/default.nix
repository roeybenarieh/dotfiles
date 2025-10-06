{ pkgs, namespace, lib, config, inputs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop;
  reload_qtile_command = "${getExe pkgs.qtile-unwrapped} cmd-obj -o cmd -f reload_config";
  blueooth-icon = pkgs.fetchurl {
    url = "https://upload.wikimedia.org/wikipedia/commons/e/ed/Antu_bluetooth.svg";
    sha256 = "sha256-JfGCuTF2o9X0iiUTemolD7eGFrrKPN8ArAJ6szFiY3o=";
  };
  volume-control-icon = pkgs.fetchurl {
    url = "https://upload.wikimedia.org/wikipedia/commons/a/a0/Circle-icons-speaker.svg";
    sha256 = "sha256-qvAZqJNs2RMQMg5N6WrH/JROFPQoDjyawYQO9vJcxIw=";
  };
  xserver-icon = pkgs.fetchurl {
    url = "https://upload.wikimedia.org/wikipedia/commons/thumb/9/90/X.Org_Logo.svg/1024px-X.Org_Logo.svg.png";
    sha256 = "sha256-7OL0wemiIgMHkXSRxSuWZRzlH3nMKtlCidX/Ypp+fdc=";
  };
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
    xdg.desktopEntries.picom = {
      name = "picom";
      noDisplay = true;
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
      blueberry # bluetooth manager
      xkb-switch # for switching keyboard layouts
      networkmanager_dmenu
    ];

    # manually set blueberry desktop entry in order to have icon
    xdg.desktopEntries.blueberry = {
      name = "Bluetooth";
      genericName = "Bluetooth Settings";
      comment = "Manage Bluetooth devices";
      exec = getExe' pkgs.blueberry "blueberry";
      icon = blueooth-icon;
      terminal = false;
      type = "Application";
      categories = [ "Settings" "HardwareSettings" ];
    };
    # manually set pavucontrol desktop entry in order to have icon
    xdg.desktopEntries."org.pulseaudio.pavucontrol" = {
      name = "volume control";
      genericName = "audio mixer";
      comment = "control the volume of your audio devices";
      exec = getExe pkgs.pavucontrol;
      icon = volume-control-icon;
      terminal = false;
      type = "Application";
      categories = [ "Settings" "HardwareSettings" ];
    };
    # manually set arandr desktop entry in order to have icon
    xdg.desktopEntries.arandr = {
      name = "Display Settings";
      genericName = "Screen Layout Editor";
      comment = "Graphically manage screen layouts and resolutions";
      exec = getExe pkgs.arandr;
      icon = xserver-icon;
      terminal = false;
      type = "Application";
      categories = [ "Settings" "HardwareSettings" "Utility" ];
    };


    # map WinKey(mod) short press to F1, used by qtile
    services.xcape = {
      enable = true;
      mapExpression = {
        "Super_L" = "F1";
      };
    };

    # windows-switcher/application-lancher
    programs.rofi = {
      enable = true;
      cycle = true;
      terminal = config.home.sessionVariables.TERM;
      # plugins = with pkgs; [
      #   rofi-bluetooth
      # ];
    };

    # notification daemon used by qtile
    services.dunst = {
      enable = true;
      settings.global = {
        frame_width = 0;
        gap_size = 5;
      };
    };

    # audio visualizer
    programs.cava = enabled;

    # clipboard manager
    services.clipmenu.enable = true;

    xdg.configFile = {
      "networkmanager-dmenu".source = ./networkmanager-dmenu;
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
          application_launcher = "${getExe pkgs.rofi} -show drun -config ${./rofi/applications-config.rasi}";
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
      "rofi".source = ./rofi;
    };
  };
}
