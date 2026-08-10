{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland.session;

  excludedBins = [
    "waybar"
    "wayland-bar"
    "hypridle"
    "hyprlock"
    "hyprpaper"
    "dunst"
    "mako"
    "swww"
    "swww-daemon"
    "swaybg"
    "wlsunset"
    "gammastep"
    "pipewire"
    "wireplumber"
    "xdg-desktop-portal"
    "xdg-desktop-portal-hyprland"
    "cliphist"
    "wl-paste"
    "wayle"
    "hypr-restore-session"
  ];

  excludeArray = concatStringsSep " " (map (s: ''"${s}"'') excludedBins);

  saveSession = pkgs.writeShellApplication {
    name = "hypr-save-session";
    runtimeInputs = with pkgs; [ hyprland jq ];
    text = ''
      CACHE_FILE="''${XDG_CACHE_HOME:-$HOME/.cache}/hypr-session.json"
      EXCLUDE=(${excludeArray})

      # Bail out if Hyprland is not running
      hyprctl -j monitors &>/dev/null || exit 0

      entries=()
      while IFS=' ' read -r workspace pid; do
        exe=$(readlink -f "/proc/$pid/exe" 2>/dev/null || true)
        [ -n "$exe" ] || continue
        [ -x "$exe" ] || continue
        cmd=$(basename "$exe")

        skip=false
        for excl in "''${EXCLUDE[@]}"; do
          [[ "$cmd" == "$excl" ]] && { skip=true; break; }
        done
        $skip && continue

        entries+=("{\"workspace\":$workspace,\"cmd\":\"$cmd\"}")
      done < <(hyprctl -j clients | jq -r '.[] | "\(.workspace.id) \(.pid)"')

      (IFS=,; printf '[%s]' "''${entries[*]}") | jq '.' > "$CACHE_FILE"
    '';
  };

  restoreSession = pkgs.writeShellApplication {
    name = "hypr-restore-session";
    runtimeInputs = with pkgs; [ hyprland jq ];
    text = ''
      CACHE_FILE="''${XDG_CACHE_HOME:-$HOME/.cache}/hypr-session.json"

      [ -f "$CACHE_FILE" ] || exit 0

      # Give Hyprland a moment to settle before launching apps
      sleep 3

      while IFS= read -r entry; do
        workspace=$(jq -r '.workspace' <<< "$entry")
        cmd=$(jq -r '.cmd' <<< "$entry")

        command -v "$cmd" &>/dev/null || continue
        hyprctl dispatch exec "[workspace $workspace silent] $cmd" || true
      done < <(jq -c '.[]' "$CACHE_FILE")
    '';
  };
in
{
  options.${namespace}.desktop.hyprland.session = with types; {
    enable = mkBoolOpt false "Save and restore the Hyprland window session across reboots.";
  };

  config = mkIf cfg.enable {
    home.packages = [ saveSession restoreSession ];

    # Periodically save the session while Hyprland is active so a recent
    # snapshot exists even if Hyprland crashes or the machine is power-cycled.
    systemd.user.services.hypr-save-session = {
      Unit = {
        Description = "Save current Hyprland session state";
        After = [ "hyprland-session.target" ];
        PartOf = [ "hyprland-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${saveSession}/bin/hypr-save-session";
      };
    };

    systemd.user.timers.hypr-save-session = {
      Unit.Description = "Periodically save Hyprland session state";
      Timer = {
        OnStartupSec = "30s";
        OnUnitInactiveSec = "5min";
        Unit = "hypr-save-session.service";
      };
      Install.WantedBy = [ "hyprland-session.target" ];
    };

    # Restore the saved session when Hyprland starts.
    wayland.windowManager.hyprland.extraConfig = ''
      hl.on("hyprland.start", function()
        hl.dispatch(hl.dsp.exec_cmd("${restoreSession}/bin/hypr-restore-session"))
      end)
    '';
  };
}
