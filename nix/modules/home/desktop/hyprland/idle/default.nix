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
  # Dim by 30% of the current brightness (e.g. 30% -> 21%).
  dimBy30 = pkgs.writeShellScript "idle-dim" ''
    current=$(${brightnessctl} get)
    ${brightnessctl} -s set "$((current * 70 / 100))"
  '';
  # Restore the saved brightness, but never below 10% of max.
  restoreMin10 = pkgs.writeShellScript "idle-restore" ''
    ${brightnessctl} -r
    min=$(( $(${brightnessctl} max) * 10 / 100 ))
    if [ "$(${brightnessctl} get)" -lt "$min" ]; then
      ${brightnessctl} set "$min"
    fi
  '';
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
            ignore_inhibit = false;
            on-timeout = "${dimBy30}";
            on-resume = "${restoreMin10}";
          }
          {
            # 5 min: lock screen.
            timeout = 300;
            ignore_inhibit = false;
            on-timeout = lockCmd;
          }
          {
            # 5 min, 5 sec: power off screens
            timeout = 305;
            ignore_inhibit = false;
            on-timeout = dpmsOff;
            on-resume = dpmsOn;
          }
          {
            # 10 min: suspend, then hibernate according to the system sleep policy.
            timeout = 600;
            # Exit 0 allows on-timeout to run; nonzero defers it.
            condition_cmd = concatStringsSep " " [
              "${pkgs.systemd}/bin/busctl --system get-property"
              "org.freedesktop.login1 /org/freedesktop/login1"
              "org.freedesktop.login1.Manager BlockInhibited"
              "| ${pkgs.gnugrep}/bin/grep -qvE '(^|[:\"])(sleep|idle)([:\"]|$)'"
            ];
            condition_retry = 5; # 5s beteen each retry
            on-timeout = "systemctl suspend-then-hibernate";
            on-resume = lockCmd;
          }
        ];
      };
    };
  };
}
