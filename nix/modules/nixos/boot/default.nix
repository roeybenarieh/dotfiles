{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.boot;
in
{
  options.${namespace}.boot = with types; {
    enable = mkBoolOpt true "Whether or not to enable boot configuration.";
  };

  config = mkIf cfg.enable {
    boot.loader = {
      timeout = 2;
      systemd-boot = {
        enable = true;
        configurationLimit = 50; # limit the amount of boot options
        # disable editing kernel command-line before boot, 
        # prevents access to root in case of physical access to the machine.
        editor = false;
      };
      efi.canTouchEfiVariables = true;
    };
  };
}
 
