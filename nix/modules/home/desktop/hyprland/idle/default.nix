{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland.idle;
  brightnessctl = getExe pkgs.brightnessctl;
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  dpmsOn  = "${hyprctl} dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
  dpmsOff = "${hyprctl} dispatch 'hl.dsp.dpms({ action = \"disable\" })'";
  lockCmd = config.xdg.desktopEntries.power-logout.exec;
in
{
  options.${namespace}.desktop.hyprland.idle = with types; {
    enable = mkBoolOpt false "Enable hypridle idle/power pipeline for Hyprland.";
  };

  config = mkIf cfg.enable {
    services.hypridle = {
      enable = true;
      settings = {
        general = {
          # Lock the screen before the system suspends so we never wake to an unlocked session.
          before_sleep_cmd = lockCmd;
          after_sleep_cmd = dpmsOn;
          # Respect DBus inhibitors set by media players (audio suppression).
          ignore_dbus_inhibit = false;
        };

        listener = [
          {
            # 2.5 min: dim to 30% and restore on activity.
            timeout = 150;
            on-timeout = "${brightnessctl} -s set 30%";
            on-resume = "${brightnessctl} -r";
          }
          {
            # 5 min: lock screen + screen off.
            timeout = 300;
            on-timeout = lockCmd;
          }
          {
            # 5 min, 5 sec: power off screens
            timeout = 305;
            on-timeout = dpmsOff;
            on-resume = dpmsOn;
          }
          {
            # 10 min: suspend+hibernate. AC caffeine (nixos module) blocks this while plugged in.
            timeout = 600;
            on-timeout = "systemctl suspend-then-hibernate";
            on-resume = lockCmd;
          }
        ];
      };
    };
  };
}
