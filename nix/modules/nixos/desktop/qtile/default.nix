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
      # displayManager.lightdm.enable = true;
      windowManager.qtile = {
        enable = true;
        # qtile 0.35.0 tests are broken on Python 3.13; intercept .override so
        # doCheck = false survives the nixos module's finalPackage re-instantiation
        package =
          let qtile = pkgs.python3.pkgs.qtile;
          in qtile // {
            override = args: (qtile.override args).overrideAttrs (_: { doInstallCheck = false; });
          };
        extraPackages = python3Packages: with python3Packages; [
          qtile-extras
          pydexcom
          colour
          pydantic
        ];
      };
    };

    services.displayManager.sessionPackages = [ pkgs.python3.pkgs.qtile ];
    # Enable the corresponding configuration at the user level.
    snowfallorg.users.roey.home.config.${namespace}.desktop = mkForce enabled;
  };
}
 
