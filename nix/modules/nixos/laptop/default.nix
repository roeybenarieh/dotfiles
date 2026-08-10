{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.laptop;
in
{
  options.${namespace}.laptop = with types; {
    enable = mkBoolOpt false "Whether or not to enable laptop features.";
  };

  config = mkIf cfg.enable {
    # Remap laptop Fn-row keys to their XF86 equivalents so Hyprland bindings
    # and system tools pick them up without any per-app configuration.
    services.keyd = {
      enable = true;
      keyboards.default = {
        ids = [ "*" ];
        settings.main = {
          f1 = "mute"; # speaker mute
          f2 = "volumedown";
          f3 = "volumeup";
          f4 = "micmute"; # microphone mute
          f5 = "brightnessdown";
          f6 = "brightnessup";
          f8 = "rfkill"; # airplane mode toggle
          f10 = "coffee"; # lock screen (XF86ScreenSaver)
        };
      };
    };

    # Enable touchpad support
    services.libinput = {
      enable = true;
      touchpad = {
        accelProfile = "flat";
        accelStepScroll = 0.001;
        horizontalScrolling = true;
        naturalScrolling = true;
        disableWhileTyping = true;
        # Right-click via bottom-right corner tap area.
        clickMethod = "buttonareas";
      };
    };

    environment = {
      # configuration docs at https://github.com/bulletmark/libinput-gestures/blob/master/libinput-gestures.conf
      # FIX: in firefox/chromium: when swiping 3 fingers to the right it goes backwards and vise versa(against natural logic)
      # etc."libinput-gestures.conf".text = ''
      #   gesture swipe right 3 ${getExe pkgs.bash} -c '
      #     user=$(${pkgs.systemd}/bin/loginctl show-user $(${pkgs.systemd}/bin/loginctl | awk "/seat0/ {print \$1}") -p Name --value)
      #     export DISPLAY=:0
      #     export XAUTHORITY=/home/$user/.Xauthority
      #     DISPLAY=:0 XAUTHORITY=/home/$user/.Xauthority ${getExe pkgs.xdotool} key --clearmodifiers ctrl+Tab
      #   '
      # '';

      systemPackages = with pkgs; [
        libinput-gestures
        wmctrl # needed by libinput-gestures to switch workspaces
        xdotool
        bluejay # bluetooth manager
      ];
    };

    # enable bluetooth
    hardware.bluetooth = {
      enable = true;
      settings.General.Experimental = true; # required for some features on newer iOS versions
    };

    # hardware.bluetooth.powerOnBoot doesn't work reliably; power on bluetooth via a systemd service instead
    systemd.services.bluetooth-power-on = {
      description = "Power on Bluetooth adapter at boot";
      after = [ "bluetooth.service" ];
      requires = [ "bluetooth.service" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.util-linux}/bin/rfkill unblock bluetooth";
        RemainAfterExit = true;
      };
    };

    # taken from : https://nixos.wiki/wiki/Laptop
    # power management
    powerManagement = {
      enable = true;
      powertop.enable = true;
    };
    networking.networkmanager.wifi.powersave = true;
    # cpu thermal management
    services.thermald.enable = true;
    # cpu usage management
    services.auto-cpufreq = {
      enable = true;
      settings = {
        battery = {
          governor = "powersave";
          turbo = "never";
        };
        charger = {
          governor = "performance";
          turbo = "auto";
        };
      };
    };
    services.power-profiles-daemon = disabled;
    # # battery management
    # # FIX: this doesn't work for my lenovo laptop
    # services.tlp = {
    #   enable = false;
    #   settings = {
    #     # helps save long term battery health
    #     START_CHARGE_THRESH_BAT0 = 40; # 40 and below it starts to charge
    #     STOP_CHARGE_THRESH_BAT0 = 80; # 80 and above it stops charging
    #   };
    # };
    #
    # # better suspend+hibernate
    # # more info: https://www.mankier.com/5/logind.conf#Options-HandleLidSwitch
    # services.logind.settings.Login = {
    #   HandleLidSwitch = "hibernate";
    #   HandleLidSwitchDocked = "hibernate";
    #   HandleLidSwitchExternalPower = "hibernate";
    #   KillUserProcesses = true;
    #
    #   SuspendKeyIgnoreInhibited = "yes";
    #   HibernateKeyIgnoreInhibited = "yes";
    #   RebootKeyIgnoreInhibited = "yes";
    #   LidSwitchIgnoreInhibited = "yes";
    # };
    # systemd.sleep.extraConfig = ''
    #   HibernateDelaySec=5m # hibernate 5 minutes after suspend(or the battery is less than 5%)
    # '';

  };
}
