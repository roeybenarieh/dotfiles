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
    services.libinput.enable = true;

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
  };
}
