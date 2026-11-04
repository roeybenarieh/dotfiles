{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland.screensaver;
  lua = lib.generators.mkLuaInline;
  papirus = pkgs.papirus-icon-theme;
  icon = name: "${papirus}/share/icons/Papirus/48x48/apps/${name}.svg";
  colors = config.lib.stylix.colors;
  font = config.stylix.fonts.sansSerif.name;
  iconFont = config.stylix.fonts.monospace.name;
  foreground = "rgba(${colors.base05}b3)";
  musicCache = "${config.xdg.cacheHome}/hyprlock-music";
  cachedMusic = field: "cmd[update:1000] ${pkgs.coreutils}/bin/cat ${lib.escapeShellArg "${musicCache}/${field}"} 2>/dev/null";
  # Vector avatar recolored from Stylix, then rasterized for hyprlock (which
  # does not read SVG). Figure and background use Stylix colors that the music
  # widgets don't use (base02 shape, base05 text, base0D fallback art).
  avatar = pkgs.runCommand "hyprlock-avatar.png" { nativeBuildInputs = [ pkgs.librsvg ]; } ''
    sed -e 's/@foreground@/#${colors.base0E}/' ${./user-avatar.svg} > avatar.svg
    rsvg-convert -w 320 -h 320 -b '#${colors.base00}' avatar.svg -o $out
  '';

  # Shown in the album-art slot when no music is playing: a flat Stylix accent.
  fallbackArt = pkgs.runCommand "hyprlock-fallback-art.png" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    magick -size 320x320 xc:'#${colors.base0D}' $out
  '';

  # Music widget (pkgs.extra.hyprlock-music, Rust, MPRIS over D-Bus). Wrapped
  # so curl and ImageMagick are on PATH and the Stylix settings are set.
  hyprlockMusic = pkgs.runCommand "hyprlock-music" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
    makeWrapper ${pkgs.extra.hyprlock-music}/bin/hyprlock-music $out/bin/hyprlock-music \
      --prefix PATH : ${lib.makeBinPath [
        pkgs.curl
        pkgs.imagemagick
      ]} \
      --set HYPRLOCK_MUSIC_FONT ${lib.escapeShellArg font} \
      --set HYPRLOCK_MUSIC_FOREGROUND ${lib.escapeShellArg colors.base05} \
      --set HYPRLOCK_MUSIC_CACHE_DIR ${lib.escapeShellArg musicCache} \
      --set HYPRLOCK_MUSIC_FALLBACK_ART ${fallbackArt}
  '';
  music = "${hyprlockMusic}/bin/hyprlock-music";

  # Locks the session. Runs hyprlock once; a second instance would fight the
  # first for the session lock and keyboard focus.
  lockCmd = pkgs.writeShellScript "hyprlock-us" ''
    ${pkgs.procps}/bin/pgrep -x hyprlock >/dev/null && exit 0

    ${pkgs.hyprland}/bin/hyprctl switchxkblayout all 0

    exec ${config.programs.hyprlock.package}/bin/hyprlock
  '';
in
{
  options.${namespace}.desktop.hyprland.screensaver = with types; {
    enable = mkBoolOpt false "Enable hyprlock screensaver/lock screen.";
  };

  config = mkIf cfg.enable {
    # Warm metadata, fitted text and album artwork before the screen is locked.
    # Hyprlock only reads the finished files; network/image work never blocks it.
    systemd.user.services.hyprlock-music-cache = {
      Unit = {
        Description = "Prepare Hyprlock music widgets";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${music} --watch";
        Restart = "always";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    xdg.desktopEntries.power-logout = {
      name = "Logout";
      exec = "${lockCmd}";
      icon = icon "system-log-out";
      categories = [ "System" ];
    };

    programs.hyprlock = let
      settings = {
        background = {
          monitor = "";
          blur_passes = 2;
          contrast = 0.8916;
          brightness = 0.8172;
          vibrancy = 0.1696;
          vibrancy_darkness = 0.0;
        };

        general = {
          ignore_empty_input = true;
          immediate_render = true;
          hide_cursor = false;
        };

        animations = {
          animation = [
            "fade, 1, 6, default"
            "fadeIn, 0"
            "fadeOut, 1, 6, default"
          ];
        };

        input-field = {
          monitor = "";
          size = "13.02%, 5.09%";
          outline_thickness = 0;
          dots_size = 0.2;
          dots_spacing = 0.2;
          dots_center = true;
          fade_on_empty = false;
          font_family = "${font} Bold Italic";
          placeholder_text = "Enter Pass";
          hide_input = false;
          position = "0%, -14.17%";
          halign = "center";
          valign = "center";
        };

        label = [
          # Clock and date
          {
            monitor = "";
            text = "$TIME";
            color = foreground;
            font_size = 140;
            font_family = "${font} Bold";
            position = "0%, 24.07%";
            halign = "center";
            valign = "center";
          }
          {
            monitor = "";
            text = ''cmd[update:60000] date +"%A, %d %B"'';
            color = foreground;
            font_size = 30;
            font_family = "${font} Bold";
            position = "0%, 13.89%";
            halign = "center";
            valign = "center";
          }
          # Lock icon
          {
            monitor = "";
            text = "<span> </span>";
            color = foreground;
            font_size = 24;
            font_family = iconFont;
            position = "0.10%, -10.19%";
            halign = "center";
            valign = "top";
          }
          # Username greeting
          {
            monitor = "";
            text = "Hi, $USER";
            color = foreground;
            font_size = 20;
            font_family = "${font} Bold Italic";
            position = "0%, -9.26%";
            halign = "center";
            valign = "center";
          }
          # Track information
          {
            monitor = "";
            text = cachedMusic "title";
            color = foreground;
            font_size = 16;
            font_family = "${font} Bold";
            # Share the timeline's center; long text is fitted by the music script.
            position = "2.86%, 12.78%";
            halign = "center";
            valign = "bottom";
            zindex = 1;
          }
          {
            monitor = "";
            text = cachedMusic "player";
            color = foreground;
            font_size = 13;
            font_family = "${font} Bold";
            position = "9.64%, 4.17%";
            halign = "center";
            valign = "bottom";
            zindex = 1;
          }
          {
            monitor = "";
            text = "cmd[update:1000] printf '󰠃  '; ${pkgs.coreutils}/bin/cat ${lib.escapeShellArg "${musicCache}/artist"} 2>/dev/null";
            color = foreground;
            font_size = 12;
            font_family = font;
            position = "2.86%, 10.93%";
            halign = "center";
            valign = "bottom";
            zindex = 1;
          }
          # Playback controls
          {
            monitor = "";
            text = "󰒮";
            color = foreground;
            font_family = iconFont;
            font_size = 25;
            onclick = "${pkgs.playerctl}/bin/playerctl previous";
            position = "-0.26%, 5.09%";
            halign = "center";
            valign = "bottom";
          }
          {
            monitor = "";
            text = cachedMusic "status";
            color = foreground;
            font_family = iconFont;
            font_size = 25;
            onclick = "${pkgs.playerctl}/bin/playerctl play-pause";
            position = "2.86%, 5.09%";
            halign = "center";
            valign = "bottom";
          }
          {
            monitor = "";
            text = "󰒭";
            color = foreground;
            font_family = iconFont;
            font_size = 25;
            onclick = "${pkgs.playerctl}/bin/playerctl next";
            position = "5.73%, 5.09%";
            halign = "center";
            valign = "bottom";
          }
          # Progress display
          {
            monitor = "";
            text = "cmd[update:1000] ${music} --position";
            color = foreground;
            font_size = 10;
            font_family = font;
            # Vertically centered on the bar: (8.80% of 1080 + 6px) - 17px/2 label height.
            position = "-3.39%, 8.57%";
            halign = "center";
            valign = "bottom";
          }
          {
            monitor = "";
            text = "cmd[update:1000] ${music} --length";
            color = foreground;
            font_size = 10;
            font_family = font;
            position = "9.11%, 8.57%";
            halign = "center";
            valign = "bottom";
          }
          # Redraws the progress PNG below; prints nothing, so the label stays empty.
          {
            monitor = "";
            text = "cmd[update:200] ${music} --progress-image";
            color = foreground;
            font_size = 1;
            font_family = font;
            position = "2.86%, 8.80%";
            halign = "center";
            valign = "bottom";
          }
        ];

        image = [
          # Profile photo
          {
            monitor = "";
            path = "${avatar}";
            border_size = 0;
            size = 160;
            rounding = -1;
            rotate = 0;
            reload_time = -1;
            position = "0%, 1.39%";
            halign = "center";
            valign = "center";
          }
          # Progress bar (drawn by hyprlock-music --progress-image). Height in px;
          # the image shows 176px wide (the old text bar's width). Reloads at most once a second.
          {
            monitor = "";
            path = "${musicCache}/progress.png";
            size = 12;
            border_size = 0;
            rounding = 0;
            rotate = 0;
            reload_time = 1;
            position = "2.86%, 8.80%";
            halign = "center";
            valign = "bottom";
            zindex = 1;
          }
          # Album art
          {
            monitor = "";
            path = "${musicCache}/current.jpg";
            size = 100;
            rounding = 5;
            border_size = 0;
            rotate = 0;
            reload_time = 1;
            # Music geometry uses a 1920x1080 reference; the launcher scales
            # the entire panel uniformly for each monitor, including this image.
            # Center the 100px art inside the 140px panel: 40 + (140 - 100) / 2 = 60px.
            position = "-8%, 5.55%";
            halign = "center";
            valign = "bottom";
            zindex = 1;
          }
        ];

        shape = [
          {
            monitor = "";
            color = "rgba(${colors.base02}66)";
            # Left edge sits with a little padding outside the album art.
            size = "24.72%, 12.96%";
            rounding = 10;
            position = "0.66%, 3.70%";
            halign = "center";
            valign = "bottom";
            zindex = 0;
          }
        ];
      };
      isMusic = widget: (widget.valign or "") == "bottom";
      block = kind: widget:
        "${kind} {\n" + concatStrings (mapAttrsToList (k: v: "    ${k} = ${toString v}\n") widget) + "}\n";
      musicTemplate = pkgs.writeText "hyprlock-music.tmpl" (concatStrings (
        map (block "shape") settings.shape
        ++ map (block "label") (filter isMusic settings.label)
        ++ map (block "image") (filter isMusic settings.image)
      ));
      musicConfig = "${config.xdg.cacheHome}/hyprlock-music.conf";
      # Compiled with its unit test, so a failing test fails the build.
      musicLayout = pkgs.runCommandCC "hyprlock-music-layout" { nativeBuildInputs = [ pkgs.rustc ]; } ''
        rustc --edition 2021 --test ${./music-layout.rs} -o test && ./test
        mkdir -p $out/bin
        rustc --edition 2021 -O ${./music-layout.rs} -o $out/bin/hyprlock-music-layout
      '';
      # Regenerated at every lock so it matches the monitors connected right now.
      layoutCmd = pkgs.writeShellScript "hyprlock-music-layout" ''
        ${pkgs.hyprland}/bin/hyprctl -j monitors \
          | ${pkgs.jq}/bin/jq -r '.[] | [.name, .width, .height, .transform] | @tsv' \
          | ${musicLayout}/bin/hyprlock-music-layout ${musicTemplate} ${musicConfig} \
          || : > ${musicConfig}
      '';
    in {
      enable = true;
      package = pkgs.symlinkJoin {
        name = "hyprlock-responsive";
        paths = [ pkgs.hyprlock ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = "wrapProgram $out/bin/hyprlock --run ${layoutCmd}";
      };
      settings = settings // {
        source = musicConfig;
        label = builtins.filter (widget: !isMusic widget) settings.label;
        image = builtins.filter (widget: !isMusic widget) settings.image;
        shape = [];
      };
    };

    wayland.windowManager.hyprland.settings.bind = [
      { _args = [ "XF86ScreenSaver" (lua ''hl.dsp.exec_cmd("${lockCmd}")'') ]; }
      { _args = [ "SUPER + L"       (lua ''hl.dsp.exec_cmd("${lockCmd}")'') ]; }
    ];
  };
}
