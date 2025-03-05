{ ... }:
{
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
      ];
    };
  };
}
