{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland;
  terminal = config.home.sessionVariables.TERMINAL;
  browser = config.home.sessionVariables.BROWSER;
  lua = lib.generators.mkLuaInline;
  playerctl = getExe pkgs.playerctl;
  brightnessctl = getExe pkgs.brightnessctl;
in
{
  options.${namespace}.desktop.hyprland = with types; {
    enable = mkBoolOpt false "Whether or not to enable Hyprland home configuration.";
    systemd.enable = mkBoolOpt true "Whether to enable systemd integration for Hyprland.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      wdisplays
      pkgs.brightnessctl
    ];

    # Per-window keyboard layout (us/il): each window remembers its own
    # layout; new windows start on the first layout (us). No native HM
    # option exists for this daemon, hence the manual user service.
    systemd.user.services.hyprland-per-window-layout = {
      Unit = {
        Description = "Per-window keyboard layout for Hyprland";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.hyprland-per-window-layout}/bin/hyprland-per-window-layout";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    wayland.windowManager.hyprland = {
      enable = true;
      configType = "lua";
      systemd.enable = cfg.systemd.enable;

      settings = {
        monitor = {
          output = "";
          mode = "preferred";
          position = "auto";
          scale = 1;
        };

        # GTK4 backend fixes jumpy/discrete touchpad scrolling in LibreOffice on
        # Wayland — GTK3 discretizes smooth axis events, GTK4 handles them properly.
        env = [
          { _args = [ "SAL_USE_VCLPLUGIN" "gtk4" ]; }
        ];

        # Main Hyprland config. Stylix auto-injects border/group/shadow colors here.
        config = {
          ecosystem.no_update_news = true;
          general = {
            gaps_in = 5;
            gaps_out = 10;
            border_size = 2;
            layout = "dwindle";
            # override Stylix's inactive border — we want no border for inactive windows
            "col.inactive_border" = mkForce "rgba(00000000)";
          };
          decoration.rounding = 10;
          animations.enabled = true;
          input = {
            kb_layout = "us,il";
            kb_options = "grp:alt_shift_toggle,grp:win_space_toggle";
            numlock_by_default = true;
            follow_mouse = 1;
            sensitivity = 0;
            touchpad = {
              natural_scroll = true;
              disable_while_typing = true;
            };
          };
          dwindle.preserve_split = true;
          misc = {
            force_default_wallpaper = 0;
            disable_hyprland_logo = true;
          };
        };

        curve = {
          _args = [
            "ease"
            { type = "bezier"; points = [ [ 0.05 0.9 ] [ 0.1 1.05 ] ]; }
          ];
        };

        animation = [
          { leaf = "windows";    enabled = true; speed = 7;  bezier = "ease"; }
          { leaf = "windowsOut"; enabled = true; speed = 7;  bezier = "default"; style = "popin 80%"; }
          { leaf = "border";     enabled = true; speed = 10; bezier = "default"; }
          { leaf = "fade";       enabled = true; speed = 7;  bezier = "default"; }
          { leaf = "workspaces"; enabled = true; speed = 6;  bezier = "default"; }
        ];

        gesture = [
          { fingers = 3; direction = "horizontal"; action = "workspace"; }
        ];

        config.gestures.workspace_swipe_use_r = true;

        bind = [
          { _args = [ "XF86AudioRaiseVolume"  (lua ''hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+")'')          { repeating = true; locked = true; } ]; }
          { _args = [ "XF86AudioLowerVolume"  (lua ''hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")'')          { repeating = true; locked = true; } ]; }
          { _args = [ "XF86AudioMute"         (lua ''hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")'')        { repeating = true; locked = true; } ]; }
          { _args = [ "XF86AudioMicMute"      (lua ''hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")'')     { locked = true; } ]; }
          { _args = [ "XF86AudioPlay"         (lua ''hl.dsp.exec_cmd("${playerctl} play-pause")'')                          { locked = true; } ]; }
          { _args = [ "XF86AudioPrev"         (lua ''hl.dsp.exec_cmd("${playerctl} previous")'')                            { locked = true; } ]; }
          { _args = [ "XF86AudioNext"         (lua ''hl.dsp.exec_cmd("${playerctl} next")'')                                { locked = true; } ]; }
          { _args = [ "XF86AudioStop"         (lua ''hl.dsp.exec_cmd("${playerctl} stop")'')                                { locked = true; } ]; }
          { _args = [ "XF86MonBrightnessUp"   (lua ''hl.dsp.exec_cmd("${brightnessctl} set 5%+")'')                        { repeating = true; locked = true; } ]; }
          { _args = [ "XF86MonBrightnessDown" (lua ''hl.dsp.exec_cmd("${brightnessctl} set 5%-")'')                        { repeating = true; locked = true; } ]; }

          { _args = [ "SUPER + Return"  (lua ''hl.dsp.exec_cmd("${terminal}")'') ]; }
          { _args = [ "SUPER + B"       (lua ''hl.dsp.exec_cmd("${browser}")'') ]; }
          { _args = [ "SUPER + E"       (lua ''hl.dsp.exec_cmd("xdg-open .")'') ]; }

          { _args = [ "SUPER + Q" (lua "hl.dsp.window.close()") ]; }
          { _args = [ "SUPER + F" (lua "hl.dsp.window.fullscreen()") ]; }

          { _args = [ "SUPER + CTRL + H" (lua ''hl.dsp.focus({ direction = "left" })'') ]; }
          { _args = [ "SUPER + CTRL + J" (lua ''hl.dsp.focus({ direction = "down" })'') ]; }
          { _args = [ "SUPER + CTRL + K" (lua ''hl.dsp.focus({ direction = "up" })'') ]; }
          { _args = [ "SUPER + CTRL + L" (lua ''hl.dsp.focus({ direction = "right" })'') ]; }

          { _args = [ "SUPER + CTRL + SHIFT + H" (lua ''hl.dsp.window.move({ direction = "left" })'') ]; }
          { _args = [ "SUPER + CTRL + SHIFT + J" (lua ''hl.dsp.window.move({ direction = "down" })'') ]; }
          { _args = [ "SUPER + CTRL + SHIFT + K" (lua ''hl.dsp.window.move({ direction = "up" })'') ]; }
          { _args = [ "SUPER + CTRL + SHIFT + L" (lua ''hl.dsp.window.move({ direction = "right" })'') ]; }

          { _args = [ "SUPER + P"           (lua ''hl.dsp.exec_cmd("wdisplays")'') ]; }
          { _args = [ "SUPER + SHIFT + left"  (lua ''hl.dsp.window.move({ monitor = "l" })'') ]; }
          { _args = [ "SUPER + SHIFT + right" (lua ''hl.dsp.window.move({ monitor = "r" })'') ]; }

          { _args = [ "SUPER + mouse:272" (lua "hl.dsp.window.drag()")   { mouse = true; } ]; }
          { _args = [ "SUPER + mouse:273" (lua "hl.dsp.window.resize()") { mouse = true; } ]; }
        ];
      };

      # Workspace 1–10 bindings as a loop (cleaner than 20 explicit entries)
      extraConfig = ''
        for i = 1, 10 do
          local key = i % 10
          hl.bind("SUPER + " .. key,         hl.dsp.focus({ workspace = i }))
          hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
        end
      '';
    };

  };
}
