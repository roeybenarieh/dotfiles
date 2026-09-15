{ namespace, lib, config, pkgs, inputs, ... }:

with lib;
with lib.${namespace};

let
  cfg = config.${namespace}.desktop.displayManager.plasma;
  cursor = config.stylix.cursor;
in
{
  options.${namespace}.desktop.displayManager.plasma = with types; {
    enable = mkBoolOpt false "Whether or not to enable plasma display manager.";
  };

  config = mkIf cfg.enable {
    services.displayManager.plasma-login-manager = {
      enable = true;
      settings = {
        Users = {
          ReuseSession = true;
        };
        Greeter = {
          WallpaperPluginId = "org.kde.image";
        };
      };
    };

    environment.etc."plasmalogin.conf.d/50-wallpaper.conf".text = ''
      [Greeter][Wallpaper][org.kde.image][General]
      Image=file://${inputs.assets}/wallpaper.png
    '';

    # plasmalogin runs as the 'plasmalogin' system user; it needs input group
    # membership to read /dev/input/* devices (mouse, keyboard) in the greeter
    users.groups.input.members = [ "plasmalogin" ];

    # The plasmalogin kwin runs as a system user with no user env; set cursor vars
    # explicitly and force software rendering so the pointer is actually visible
    systemd.user.services.plasma-login-kwin_wayland = {
      overrideStrategy = "asDropin";
      environment = {
        KWIN_FORCE_SW_CURSOR = "1";
        XCURSOR_THEME = cursor.name;
      };
    };

    hardware.graphics.enable = true;
    services.libinput.enable = true;
  };
}
