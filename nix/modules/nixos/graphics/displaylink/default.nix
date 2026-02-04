{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.graphics.displaylink;
in
{
  options.${namespace}.graphics.displaylink = with types; {
    enable = mkBoolOpt false "Whether or not to enable displaylink: using computer Display/Dock via USB";
  };
  # NOTE: when first building this expression, you will get an error!
  # follow error instructions* and rebuild
  # *should be only one command with 'nix-prefetch-url'!
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      displaylink # for supporting screen monitor output via usb-c
    ];
    # Xserver specific
    services.xserver.videoDrivers = [
      "displaylink"
      "modesetting"
    ];
    # wayland specific
    boot = {
      extraModulePackages = [ config.boot.kernelPackages.evdi ];
      initrd = {
        # List of modules that are always loaded by the initrd.
        kernelModules = [
          "evdi"
        ];
      };
    };
    # Gnome specific
    systemd.services.dlm.wantedBy = [ "multi-user.target" ];
  };
}
