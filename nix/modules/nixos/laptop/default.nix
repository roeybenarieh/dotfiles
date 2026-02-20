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
      settings.Policy = {
        AutoEnable = true;
        ReconnectAttempts = 3;
      };
    };
    systemd.services.bluetooth.serviceConfig.ExecStartPost = [
      # power on bluetooth on boot(NixOS option doesnt work for Gnome desktop)
      "${pkgs.util-linux}/bin/rfkill unblock bluetooth"
      "${pkgs.bluez}/bin/bluetoothctl power on"
    ];

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
