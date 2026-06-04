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
    boot = {
      extraModulePackages = [ config.boot.kernelPackages.evdi ];
      kernelParams = [ "usbcore.autosuspend=-1" ]; # make sure input is not suspended!
      initrd.kernelModules = [ "evdi" ];
    };
    systemd.services.dlm = {
      # DLM (evdi) does periodic full-framebuffer polls causing CPU spikes.
      # Cap it hard and deprioritize it so interactive work isn't starved.
      serviceConfig = {
        CPUQuota = "350%"; # hard cap: 3.5 core
        CPUWeight = 20; # cgroups v2 relative weight (default 100) — yields when contested
        Nice = 10; # yield to foreground apps
        CPUSchedulingPolicy = "batch"; # scheduler treats it as background batch work
        IOSchedulingClass = "idle"; # lowest IO priority — never starves interactive apps
        IOSchedulingPriority = 7;
      };

    };
    # Gnome specific
    systemd.services.dlm.wantedBy = [ "multi-user.target" ];
  };
}
