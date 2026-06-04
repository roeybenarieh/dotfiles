{ namespace, lib, config, ... }:

with lib;
with lib.${namespace};

let
  cfg = config.${namespace}.desktop.sddm;
in
{
  options.${namespace}.desktop.sddm = with types; {
    enable = mkBoolOpt false "Whether or not to enable SDDM display manager.";
  };

  config = mkIf cfg.enable {
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };

    # Required for Wayland SDDM mouse/input support (Intel integrated GPU)
    hardware.graphics.enable = true;
  };
}
