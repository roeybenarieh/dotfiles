{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.qtile;
in
{
  options.${namespace}.desktop.qtile = with types; {
    enable = mkBoolOpt false "Whether or not to enable qtile windows tilling window manager.";
  };

  config = mkIf cfg.enable {
    # HACK: needed for some Gnome apps
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
    # Enable the corresponding configuration at the user level.
    snowfallorg.users.roey.home.config.${namespace}.desktop = mkForce enabled;
  };
}
 
