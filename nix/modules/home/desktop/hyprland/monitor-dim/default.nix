{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland.monitor-dim;
  monitorDim = getExe pkgs.extra.monitor-dim;
in
{
  options.${namespace}.desktop.hyprland.monitor-dim = with types; {
    enable = mkBoolOpt false ''
      Enable software brightness dimming (a Hyprland final-frame shader)
      for monitors with no real backlight/DDC-CI control, e.g.
      DisplayLink-connected displays. Tracks the real backlight device
      automatically (via inotify on its sysfs file) — every tool that sets
      brightness (brightnessctl, light, a DE's settings daemon, ...) drives
      this without needing to patch or wrap that tool. Dims all composed
      content, including shell popups and the cursor. Owns Hyprland's
      screen_shader setting and forces software cursors while running.
    '';
    skipOutputs = mkListOpt [ ]
      "Output names to exclude from dimming. Real-backlight outputs (e.g. the internal panel) still benefit from software dimming, since it can go fully black regardless of the panel's minimum backlight floor.";
    backlight = mkOpt (nullOr str) null
      "Backlight device name under /sys/class/backlight to track (e.g. \"intel_backlight\"). Null auto-detects the first device found.";
  };

  config = mkIf cfg.enable {
    systemd.user.services.monitor-dim = {
      Unit = {
        Description = "Full-frame software brightness for monitors without DDC/CI";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = concatStringsSep " " (
          [ monitorDim ]
          ++ (map (o: "--skip ${o}") cfg.skipOutputs)
          ++ optional (cfg.backlight != null) "--backlight ${cfg.backlight}"
        );
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
