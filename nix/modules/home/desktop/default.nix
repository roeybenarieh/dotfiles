{ pkgs, namespace, lib, config, inputs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop;
  reload_qtile_command = "${getExe pkgs.python3.pkgs.qtile} cmd-obj -o cmd -f reload_config";
  volume-control-icon = pkgs.fetchurl {
    url = "https://upload.wikimedia.org/wikipedia/commons/a/a0/Circle-icons-speaker.svg";
    sha256 = "sha256-qvAZqJNs2RMQMg5N6WrH/JROFPQoDjyawYQO9vJcxIw=";
  };
  xserver-icon = pkgs.fetchurl {
    url = "https://upload.wikimedia.org/wikipedia/commons/thumb/9/90/X.Org_Logo.svg/1024px-X.Org_Logo.svg.png";
    sha256 = "sha256-7OL0wemiIgMHkXSRxSuWZRzlH3nMKtlCidX/Ypp+fdc=";
  };
  network-manager-icon = pkgs.fetchurl {
    url = "https://iconvulture.com/wp-content/uploads/2019/10/si-glyph-network.png";
    sha256 = "sha256-k19dqXmpufa12yS9yBBjtzutGp2Z+kBU0KOB6z5tTx0=";
  };
  lock_screen_command = "${pkgs.systemd}/bin/loginctl lock-session self";
  lock_screen_and_sleep = "${pkgs.systemd}/bin/systemctl -i suspend-then-hibernate"; # gets locked by light-locker
  terminal = config.home.sessionVariables.TERMINAL;
in
{
  options.${namespace}.desktop = with types; {
    enable = mkBoolOpt false "Whether or not to enable desktop.";
  };

  config = mkIf cfg.enable {
    # x11 compositor with animations & rounded-corners
    services.picom = {
      enable = true;
    };
    # Override the generated service to use the custom config from xdg.configFile."picom"
    # instead of the minimal HM-generated one (which has no effects/animations).
    systemd.user.services.picom.Service.ExecStart = mkForce
      "${pkgs.picom}/bin/picom --config ${config.xdg.configHome}/picom/picom.conf";
    xdg.desktopEntries.picom = {
      name = "picom";
      noDisplay = true;
    };

    home.packages = with pkgs; [
      pamixer # control volume
      playerctl # control playing
      brightnessctl # control brightness
      gscreenshot # screenshots
      libnotify # used by gscreenshot to raise notifications
      setxkbmap # for changing keyboard layout
      btop # for viewing system resources
      arandr # for editing monitors layout(positioning them relative to each other)
      alttab # window switcher
      xkb-switch # for switching keyboard layouts
      networkmanager_dmenu # handling network connections(nmtui alternative)
      linux-wifi-hotspot # create wifi hotsport
    ];

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
    xdg.desktopEntries."networkmanager_dmenu" = {
      name = "network manager - Dmenu";
      genericName = "network manager";
      comment = "control network related objects";
      exec = getExe pkgs.networkmanager_dmenu;
      icon = network-manager-icon;
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
        "Super_L" = "F12";
      };
    };

    # windows-switcher/application-lancher
    programs.rofi = {
      enable = true;
      cycle = true;
      inherit terminal;
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

    # xserver related
    xsession = {
      enable = true;
      numlock.enable = true;
      # making lightdm compatible lock screen, every user need to run it itself
      initExtra = ''
        ${pkgs.lightlocker}/bin/light-locker --idle-hint --lock-on-lid --lock-on-suspend --lock-after-screensaver=5 &
      '';
    };

    # handling idle computer(xautolock alternative)
    services.xidlehook = {
      enable = true;
      detect-sleep = true;
      not-when-audio = true;
      not-when-fullscreen = true;
      # NOTE: The delays add onto the previous value (and the value is in seconds)
      timers = [
        {
          delay = 5 * 60;
          command = "${getExe pkgs.brightnessctl} --save set 10%";
          canceller = "${getExe pkgs.brightnessctl} --restore";
        }
        {
          # Lock the session after 10 min idle
          delay = 5 * 60;
          command = "${getExe pkgs.brightnessctl} --restore || ${lock_screen_and_sleep}";
        }
      ];
    };

    services.screen-locker = {
      enable = true;
      lockCmd = lock_screen_command;
      xautolock = disabled;
    };

    xdg.configFile = {
      "networkmanager-dmenu".source = ./networkmanager-dmenu;
      "qtile" = {
        source = ./qtile;
        onChange = reload_qtile_command;
      };
      "qtile-injection/config.json" = {
        text = builtins.toJSON rec {
          lock_screen_command = lock_screen_and_sleep;
          browser = config.home.sessionVariables.BROWSER;
          wallpaper = "${inputs.assets}/wallpaper.png";
          inherit terminal;
          font = config.stylix.fonts.monospace.name;
          screenshot_dir = "${config.home.homeDirectory}/Pictures/Screenshots";
          network_manager = "${terminal} -e nmtui";
          task_manager = "${terminal} -e ${config.home.shellAliases.htop}";
          audio_visualizer = "${terminal} -e ${getExe pkgs.cava}";
          auidio_controller = getExe pkgs.pavucontrol;
          application_launcher = "${getExe pkgs.rofi} -show drun -config ${./rofi/applications-config.rasi}";
          simple_monitors_manager = getExe pkgs.lxrandr;
        };
        onChange = reload_qtile_command;
      };
      # "rofi" = {
      #   source = ./rofi;
      #   recursive = true;
      # };
      "picom" = {
        source = ./picom;
        onChange = "systemctl --user restart picom.service || true";
      };
      "rofi".source = ./rofi;
    };
  };
}
