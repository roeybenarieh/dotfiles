{ namespace, lib, config, ... }:

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

    # enable bluetooth
    hardware.bluetooth.enable = true;

    # taken from : https://nixos.wiki/wiki/Laptop
    # power management
    powerManagement.enable = true;
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

    services.xserver.xautolock = {
      enable = true;

      # notifications
      enableNotifier = true;
      notify = 60;
      notifier = "${pkgs.libnotify}/bin/notify-send 'Locking in 60 seconds'";

      # time schedules(only when not charging)
      killtime = 20; # 20min until shutdown
      time = 10; # 10 min until lock
      extraOptions = [
        "-detectsleep" # reset schedules after computer sleeped
        "-lockaftersleep" # lock when returning from sleep
        "-secure" # prevent service shuting down
      ];
    };
  };
}
