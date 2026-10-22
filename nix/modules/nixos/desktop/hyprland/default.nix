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
    services.displayManager.defaultSession = "hyprland-uwsm";

    # Keep the compositor alive when a child process (e.g. a runaway `nix build`)
    # is OOM-killed; the default OOMPolicy=stop tears down the whole session.
    systemd.user.services."wayland-wm@".serviceConfig.OOMPolicy = "continue";

    snowfallorg.users.roey.home.config.${namespace}.desktop.hyprland = mkForce {
      enable = true;
      systemd.enable = !config.programs.hyprland.withUWSM;
    };
  };
}
