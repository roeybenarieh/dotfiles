{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland.wayle;
in
{
  options.${namespace}.desktop.hyprland.wayle = with types; {
    enable = mkBoolOpt false "Enable Wayle - Hyprland shell.";
  };

  config = mkIf cfg.enable {
    # wayle isn't in the binary cache, so it must compile from source.
    # Disabling tests cuts peak memory usage by ~3 GB (the GTK test is
    # already #[ignore]d in the source anyway).
    nixpkgs.overlays = [
      (_: prev: {
        wayle = prev.wayle.overrideAttrs (_: { doCheck = false; });
      })
    ];

    ${namespace}.desktop = {
      hyprland = {
        applicationLauncher = enabled;
        screenCapture = enabled;
        screensaver = enabled;
        idle = enabled;
        clipboard = enabled;
        windowSwitcher = enabled;
        keyboard-layout-indicator = enabled;
      };
    };

    services.wayle = {
      enable = true;
      autoInstallDependencies = true;
      settings = {
        bar = {
          location = "top";
          layout = [
            {
              monitor = "*";
              show = true;
              left = [ "dashboard" "hyprland-workspaces" ];
              center = [ "clock" ];
              right = [ "idle-inhibit" "network" "bluetooth" "battery" "volume" ];
            }
          ];
        };
        modules = {
          idle-inhibit = {
            startup-duration = 120;
            icon-show = true;
            label-show = true;
            format = "{{ remaining }}";
            left-click = "wayle idle toggle";
            right-click = "";
            scroll-up = "wayle idle remaining +5";
            scroll-down = "wayle idle remaining -5";
          };
          clock = {
            format = "%H:%M";
          };
          network = {
            icon-show = true;
            label-show = false;
            left-click = "dropdown:network";
          };
          bluetooth = {
            icon-show = true;
            label-show = false;
            left-click = "dropdown:bluetooth";
          };
          battery = {
            icon-show = true;
            label-show = true;
            left-click = "dropdown:battery";
          };
          volume = {
            scroll-up = "wayle audio output-volume +2";
            scroll-down = "wayle audio output-volume -2";
          };
          hyprland-workspaces = {
            app-icons-show = true;
            display-mode = "none";
          };
        };
        osd = {
          monitor = "*";
        };
      };
    };
  };
}
