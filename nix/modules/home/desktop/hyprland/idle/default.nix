{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland.idle;
  brightnessctl = getExe pkgs.brightnessctl;
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
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
          before_sleep_cmd = "loginctl lock-session";
          after_sleep_cmd = "${hyprctl} dispatch dpms on";
          # Respect DBus inhibitors set by media players (audio suppression).
          ignore_dbus_inhibit = false;
        };

        listener = [
          {
            # 2.5 min: dim to 10% and restore on activity.
            timeout = 150;
            on-timeout = "${brightnessctl} -s set 10%";
            on-resume = "${brightnessctl} -r";
          }
          {
            # 5 min: lock screen.
            timeout = 300;
            on-timeout = "loginctl lock-session";
          }
          {
            # 5.5 min: screen off.
            timeout = 330;
            on-timeout = "${hyprctl} dispatch dpms off";
            on-resume = "${hyprctl} dispatch dpms on";
          }
          {
            # 30 min: suspend. AC caffeine (nixos module) blocks this while plugged in.
            timeout = 1800;
            on-timeout = "systemctl suspend";
          }
        ];
      };
    };
  };
}
