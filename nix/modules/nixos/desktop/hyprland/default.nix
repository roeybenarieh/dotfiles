{ namespace, lib, config, ... }:

with lib;
with lib.${namespace};

let
  cfg = config.${namespace}.desktop.hyprland;
in
{
  options.${namespace}.desktop.hyprland = with types; {
    enable = mkBoolOpt false "Whether or not to enable Hyprland Wayland compositor.";
  };

  config = mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      withUWSM = true;
    };

    snowfallorg.users.roey.home.config.${namespace}.desktop.hyprland = mkForce {
      enable = true;
      systemd.enable = !config.programs.hyprland.withUWSM;
    };
  };
}
