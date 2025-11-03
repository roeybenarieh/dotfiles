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
    # Enable touchpad support
    services.libinput = {
      enable = true;
      touchpad = {
        accelStepScroll = 0.001;
        horizontalScrolling = true;
        disableWhileTyping = true;
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
      ];
    };

    # enable bluetooth
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.Policy.AutoEnable = true;
    };

    # Networking related
    networking = {
      # set all known connections(by name) to be autoconnected 
      localCommands = ''
        for name in $(${pkgs.networkmanager}/bin/nmcli -t -f NAME connection show); do
          ${pkgs.networkmanager}/bin/nmcli connection modify \"$name\" connection.autoconnect yes || true
        done
      '';
      wireless.iwd = {
        enable = true; # better than wpa_supplicant that is used by default
        settings = {
          Settings.AutoConnect = true;
        };
      };
    };


    # taken from : https://nixos.wiki/wiki/Laptop
    # power management
    powerManagement = {
      enable = true;
      powertop.enable = true;
    };
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

    # better suspend+hibernate
    services.logind.settings.Login.HandleLidSwitch = "suspend-then-hibernate";

  };
}
