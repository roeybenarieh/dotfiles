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
    services.xserver.videoDrivers = [
      "displaylink"
      "modesetting"
    ];
  };
}
