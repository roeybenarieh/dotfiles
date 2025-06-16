{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop;
in
{
  options.${namespace}.desktop = with types; {
    enable = mkBoolOpt false "Whether or not to enable desktop env.";
  };

  config = mkIf cfg.enable {
    # HACK: when desktopManager is not set, home manager expects dconf(for some reason)
    programs.dconf.enable = true;

    # Enable the X11 windowing system.
    # Enable the Budgie Desktop environment.
    services.xserver = {
      enable = true;
      displayManager.lightdm.enable = true;
      windowManager.qtile = {
        enable = true;
        extraPackages = python3Packages: with python3Packages; [
          qtile-extras
          pydexcom
          colour
          pydantic
        ];
      };
    };
  };
}
 
