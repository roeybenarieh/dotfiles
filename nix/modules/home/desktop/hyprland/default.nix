{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland;
  terminal = config.home.sessionVariables.TERMINAL;
  browser = config.home.sessionVariables.BROWSER;
in
{
  options.${namespace}.desktop.hyprland = with types; {
    enable = mkBoolOpt false "Whether or not to enable Hyprland home configuration.";
    systemd.enable = mkBoolOpt true "Whether to enable systemd integration for Hyprland.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      wdisplays
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
      configType = "hyprlang";
      systemd.enable = cfg.systemd.enable;

      settings = {
        ecosystem."no_update_news" = true;
        monitor = ",preferred,auto,1";

        "$mod" = "SUPER";

        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 2;
          layout = "dwindle";
          "col.inactive_border" = mkForce "rgba(00000000)"; # no border for inactive panels
        };

        decoration = {
          rounding = 10;
        };

        animations = {
          enabled = true;
          bezier = "ease, 0.05, 0.9, 0.1, 1.05";
          animation = [
            "windows, 1, 7, ease"
            "windowsOut, 1, 7, default, popin 80%"
            "border, 1, 10, default"
            "fade, 1, 7, default"
            "workspaces, 1, 6, default"
          ];
        };

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

        gesture = [ "3, horizontal, workspace" ];

        gestures = {
          workspace_swipe_use_r = true;
        };

        dwindle = {
          preserve_split = true;
        };

        # cursor = {
        #   no_hardware_cursors = true;
        # };

        misc = {
          force_default_wallpaper = 0;
          disable_hyprland_logo = true;
        };

        # GTK4 backend fixes jumpy/discrete touchpad scrolling in LibreOffice on
        # Wayland — GTK3 discretizes smooth axis events, GTK4 handles them properly.
        env = [
          "SAL_USE_VCLPLUGIN,gtk4"
        ];

        bindel = [
          ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
          ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
          ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ];

        bind = [
          # Consume $mod+Space key binding, that way nothing else can ran in the same operation.
          "$mod, space, exec, true"
          "$mod, Return, exec, ${terminal}"
          "$mod, B, exec, ${browser}"
          "$mod, E, exec, xdg-open ."
          "$mod, Q, killactive"
          "$mod, F, fullscreen"
          "$mod, H, movefocus, l"
          "$mod, L, movefocus, r"
          "$mod, K, movefocus, u"
          "$mod, J, movefocus, d"
          "$mod, 1, workspace, 1"
          "$mod, 2, workspace, 2"
          "$mod, 3, workspace, 3"
          "$mod, 4, workspace, 4"
          "$mod, 5, workspace, 5"
          "$mod, 6, workspace, 6"
          "$mod, 7, workspace, 7"
          "$mod, 8, workspace, 8"
          "$mod, 9, workspace, 9"
          "$mod, 0, workspace, 10"
          "$mod SHIFT, 1, movetoworkspace, 1"
          "$mod SHIFT, 2, movetoworkspace, 2"
          "$mod SHIFT, 3, movetoworkspace, 3"
          "$mod SHIFT, 4, movetoworkspace, 4"
          "$mod SHIFT, 5, movetoworkspace, 5"
          "$mod SHIFT, 6, movetoworkspace, 6"
          "$mod SHIFT, 7, movetoworkspace, 7"
          "$mod SHIFT, 8, movetoworkspace, 8"
          "$mod SHIFT, 9, movetoworkspace, 9"
          "$mod SHIFT, 0, movetoworkspace, 10"
          "$mod, P, exec, wdisplays"
          ", XF86ScreenSaver, exec, loginctl lock-session"
          "$mod SHIFT, left, movewindow, mon:l"
          "$mod SHIFT, right, movewindow, mon:r"
        ];

        bindm = [
          "$mod, mouse:272, movewindow"
          "$mod, mouse:273, resizewindow"
        ];
      };
    };
  };
}
