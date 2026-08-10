{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland.screensaver;
  lua = lib.generators.mkLuaInline;
  papirus = pkgs.papirus-icon-theme;
  icon = name: "${papirus}/share/icons/Papirus/48x48/apps/${name}.svg";
  playerctl = lib.getExe pkgs.playerctl;

  # Inline Material Design SVGs — white on transparent, converted to PNG at build time.
  actionIcon = name: let
    svgs = {
      "media-skip-backward" = pkgs.writeText "skip-backward.svg" ''
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
          <path fill="white" d="M6 6h2v12H6zm3.5 6 8.5 6V6z"/>
        </svg>
      '';
      "media-playback-start" = pkgs.writeText "play.svg" ''
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
          <path fill="white" d="M8 5v14l11-7z"/>
        </svg>
      '';
      "media-playback-pause" = pkgs.writeText "pause.svg" ''
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
          <path fill="white" d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/>
        </svg>
      '';
      "media-skip-forward" = pkgs.writeText "skip-forward.svg" ''
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
          <path fill="white" d="M6 18l8.5-6L6 6v12zM16 6h2v12h-2z"/>
        </svg>
      '';
    };
  in pkgs.runCommand "${name}.png" { nativeBuildInputs = [ pkgs.librsvg ]; } ''
    ${pkgs.librsvg}/bin/rsvg-convert -w 64 -h 64 ${svgs.${name}} > $out
  '';

  # Runs on every MPRIS change and at lock time.
  # Writes three cache files so hyprlock never has to call playerctl directly:
  #   label.cache           — Pango markup for the now-playing label
  #   playpause_icon.cache  — store path of the correct play/pause PNG
  #   album_art.jpg         — current album art (fetched on song change only)
  updateCacheScript = pkgs.writeShellScript "hyprlock-update-cache" ''
    CACHE_DIR="/tmp/hyprlock-nowplaying"
    LABEL_FILE="$CACHE_DIR/label.cache"
    ICON_FILE="$CACHE_DIR/playpause_icon.cache"
    ART_FILE="$CACHE_DIR/album_art.jpg"
    TITLE_CACHE="$CACHE_DIR/title.cache"
    mkdir -p "$CACHE_DIR"

    status=$(${playerctl} status 2>/dev/null)
    if [ -z "$status" ]; then
      rm -f "$ART_FILE" "$LABEL_FILE" "$TITLE_CACHE"
      printf '%s' "${actionIcon "media-playback-start"}" > "$ICON_FILE"
      exit 0
    fi

    raw_title=$(${playerctl} metadata title 2>/dev/null)
    raw_artist=$(${playerctl} metadata artist 2>/dev/null)
    player_name=$(${playerctl} metadata --format "{{playerName}}" 2>/dev/null)
    art_url=$(${playerctl} metadata mpris:artUrl 2>/dev/null)

    escape()     { printf '%s' "$1" | ${pkgs.gnused}/bin/sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }
    url_decode() { local u="''${1//+/ }"; printf '%b' "''${u//%/\x}"; }

    song_title=$(escape "$raw_title")
    song_artist=$(escape "$raw_artist")
    player_display=$(escape "$player_name")
    player_status=""
    [ "$status" != "Playing" ] && player_status="Paused"

    # Write play/pause icon path to cache — avoids any playerctl call from hyprlock
    if [ "$status" = "Playing" ]; then
      printf '%s' "${actionIcon "media-playback-pause"}" > "$ICON_FILE"
    else
      printf '%s' "${actionIcon "media-playback-start"}" > "$ICON_FILE"
    fi

    printf '<span font_weight="light" size="small" alpha="80%%">%s <small>%s</small></span>\n<b>%s</b>    <span alpha="80%%" style="italic">%s</span>' \
      "$player_display" "$player_status" "$song_title" "$song_artist" > "$LABEL_FILE"

    # Fetch art only when the song changes
    cached_title=""
    [ -f "$TITLE_CACHE" ] && cached_title=$(cat "$TITLE_CACHE")
    if [ "$raw_title" != "$cached_title" ] || [ ! -f "$ART_FILE" ]; then
      printf '%s' "$raw_title" > "$TITLE_CACHE"
      if printf '%s' "$art_url" | grep -q '^data:image'; then
        printf '%s\n' "$art_url" \
          | ${pkgs.gnused}/bin/sed 's/^data:image[^;]*;base64,//' \
          | ${pkgs.coreutils}/bin/base64 -d > "$ART_FILE" 2>/dev/null
      elif printf '%s' "$art_url" | grep -q '^file://'; then
        raw_path=$(printf '%s\n' "$art_url" | ${pkgs.gnused}/bin/sed 's,^file://,,')
        decoded_path=$(url_decode "$raw_path")
        ${pkgs.imagemagick}/bin/magick "$decoded_path" "$ART_FILE" 2>/dev/null
      elif printf '%s' "$art_url" | grep -q 'https\?://'; then
        ${pkgs.curl}/bin/curl -sf -o "$ART_FILE" "$art_url" 2>/dev/null
      fi
    fi
  '';

  # Called by hyprlock label — just reads a file, no subprocesses.
  nowPlayingScript = pkgs.writeShellScript "hyprlock-nowplaying" ''
    [ -f /tmp/hyprlock-nowplaying/label.cache ] && cat /tmp/hyprlock-nowplaying/label.cache
  '';

  # Called by hyprlock reload_cmd — just reads a file, no playerctl.
  playPauseIconScript = pkgs.writeShellScript "hyprlock-playpause-icon" ''
    if [ -f /tmp/hyprlock-nowplaying/playpause_icon.cache ]; then
      cat /tmp/hyprlock-nowplaying/playpause_icon.cache
    else
      printf '%s' "${actionIcon "media-playback-start"}"
    fi
  '';

  # onclick for play-pause: update cache immediately and signal hyprlock.
  # flock -n: if another onclick is already running, exit immediately rather
  # than queuing — rapid clicks would otherwise send bursts of SIGUSR2 that
  # crash hyprlock's signal handler (it re-entrantly modifies the timer list).
  playPauseCmd = pkgs.writeShellScript "hyprlock-cmd-playpause" ''
    exec 9>/tmp/hyprlock-nowplaying/onclick.lock
    ${pkgs.util-linux}/bin/flock -n 9 || exit 0
    ${playerctl} play-pause
    ${updateCacheScript}
    pid=$(cat /tmp/hyprlock-nowplaying/hyprlock.pid 2>/dev/null)
    [ -n "$pid" ] && kill -SIGUSR2 "$pid" 2>/dev/null
  '';

  # onclick for next/previous: brief sleep lets the player commit the new track
  # to MPRIS before we read metadata, then update cache and signal hyprlock.
  skipCmd = action: pkgs.writeShellScript "hyprlock-cmd-${action}" ''
    exec 9>/tmp/hyprlock-nowplaying/onclick.lock
    ${pkgs.util-linux}/bin/flock -n 9 || exit 0
    ${playerctl} ${action}
    sleep 0.5
    ${updateCacheScript}
    pid=$(cat /tmp/hyprlock-nowplaying/hyprlock.pid 2>/dev/null)
    [ -n "$pid" ] && kill -SIGUSR2 "$pid" 2>/dev/null
  '';

  lockCmd = pkgs.writeShellScript "hyprlock-us" ''
    ${pkgs.hyprland}/bin/hyprctl switchxkblayout all 0
    ${updateCacheScript}

    ${pkgs.hyprlock}/bin/hyprlock &
    HYPRLOCK_PID=$!
    printf '%s' "$HYPRLOCK_PID" > /tmp/hyprlock-nowplaying/hyprlock.pid

    # Wait for hyprlock to register SIGUSR2 before watchers start.
    # --follow emits current state immediately on start; the sleep absorbs that burst.
    sleep 1

    # Status watcher: fires on play/pause/stop; deduplicated so spurious repeats are ignored.
    prev_status=""
    ${playerctl} --follow status 2>/dev/null | while IFS= read -r s; do
      [ "$s" = "$prev_status" ] && continue
      prev_status="$s"
      ${updateCacheScript}
      kill -SIGUSR2 "$HYPRLOCK_PID" 2>/dev/null
    done &
    STATUS_PID=$!

    # Metadata watcher: fires on song change; deduplicated on title to ignore position updates.
    prev_title=""
    ${playerctl} --follow metadata --format "{{title}}" 2>/dev/null | while IFS= read -r t; do
      [ "$t" = "$prev_title" ] && continue
      prev_title="$t"
      ${updateCacheScript}
      kill -SIGUSR2 "$HYPRLOCK_PID" 2>/dev/null
    done &
    META_PID=$!

    wait "$HYPRLOCK_PID"
    kill "$STATUS_PID" "$META_PID" 2>/dev/null
    rm -f /tmp/hyprlock-nowplaying/hyprlock.pid
  '';
in
{
  options.${namespace}.desktop.hyprland.screensaver = with types; {
    enable = mkBoolOpt false "Enable hyprlock screensaver/lock screen.";
  };

  config = mkIf cfg.enable {
    xdg.desktopEntries.power-logout = {
      name = "Logout";
      exec = "${lockCmd}";
      icon = icon "system-log-out";
      categories = [ "System" ];
    };

    programs.hyprlock = {
      enable = true;
      settings = {
        general = {
          disable_loading_bar = true;
          grace = 0;
          hide_cursor = false;
          no_fade_in = false;
        };

        image = [
          {
            path = "/tmp/hyprlock-nowplaying/album_art.jpg";
            size = 80;
            rounding = 12;
            position = "0, -320";
            halign = "center";
            valign = "center";
            # reload_time = 0 creates a force-updatable timer: SIGUSR2 triggers
            # an immediate reload. reload_time > 0 sets force=false and SIGUSR2
            # is silently ignored (confirmed in hyprlock Image.cpp source).
            reload_time = 0;
            onclick = "${playPauseCmd}";
          }
          {
            path = "${actionIcon "media-skip-backward"}";
            size = 28;
            rounding = 0;
            position = "-60, -415";
            halign = "center";
            valign = "center";
            onclick = "${skipCmd "previous"}";
          }
          {
            path = "${actionIcon "media-playback-start"}";
            size = 28;
            rounding = 0;
            position = "0, -415";
            halign = "center";
            valign = "center";
            # reload_cmd reads from cache — instant, no playerctl.
            # reload_time = 0 enables SIGUSR2 force-update (same as album art above).
            reload_time = 0;
            reload_cmd = "${playPauseIconScript}";
            onclick = "${playPauseCmd}";
          }
          {
            path = "${actionIcon "media-skip-forward"}";
            size = 28;
            rounding = 0;
            position = "60, -415";
            halign = "center";
            valign = "center";
            onclick = "${skipCmd "next"}";
          }
        ];

        label = [
          {
            # 1 fork/minute — the only recurring background work.
            text = ''cmd[update:60000] date +"%H:%M"'';
            color = "rgba(255, 255, 255, 0.9)";
            font_size = 96;
            font_family = "Roboto Condensed Bold";
            position = "0, 80";
            halign = "center";
            valign = "center";
          }
          {
            # :true enables allowForceUpdate so SIGUSR2 fires this immediately.
            text = ''cmd[update:3600000:true] date +"%A, %B %d"'';
            color = "rgba(255, 255, 255, 0.6)";
            font_size = 20;
            font_family = "Roboto Condensed";
            position = "0, -10";
            halign = "center";
            valign = "center";
          }
          {
            # :true enables allowForceUpdate — SIGUSR2 immediately re-runs this.
            text = ''cmd[update:3600000:true] ${nowPlayingScript}'';
            color = "rgba(255, 255, 255, 0.7)";
            font_size = 16;
            font_family = "Roboto Condensed";
            position = "0, -470";
            halign = "center";
            valign = "center";
          }
        ];

        input-field = {
          size = "300, 50";
          position = "0, -200";
          halign = "center";
          valign = "center";
          dots_center = true;
          fade_on_empty = true;
          fade_timeout = 2000;
          placeholder_text = "<span foreground='##ffffff99'>Password</span>";
          hide_input = false;
          rounding = 12;
        };
      };
    };

    wayland.windowManager.hyprland.settings.bind = [
      { _args = [ "XF86ScreenSaver" (lua ''hl.dsp.exec_cmd("${lockCmd}")'') ]; }
      { _args = [ "SUPER + L"       (lua ''hl.dsp.exec_cmd("${lockCmd}")'') ]; }
    ];
  };
}
