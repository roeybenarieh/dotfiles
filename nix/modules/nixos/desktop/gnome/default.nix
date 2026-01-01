{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.gvariant;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.gnome;
in
{
  options.${namespace}.desktop.gnome = with types; {
    enable = mkBoolOpt false "Whether or not to enable Gnome desktop environment.";
  };

  config = mkIf cfg.enable {
    services = {
      displayManager.gdm = enabled;
      desktopManager.gnome = enabled;
      gnome = {
        games = disabled;
        core-developer-tools = disabled;
        core-apps = disabled;
      };
    };
    environment.systemPackages = with pkgs.gnomeExtensions; [
      user-themes
      dash-to-dock
      # noannoyance
      caffeine
      clipboard-indicator
      appindicator
      gsconnect
      # qtile like
      unite # doesnt seems to work
      undecorate # doesnt work
      rounded-corners # doesnt work

      auto-brightness-toggle
      dexcom-cgm-monitor
    ];
    # open ports required by gsconnect
    networking.firewall = {
      allowedTCPPortRanges = [{ from = 1716; to = 1764; }];
      allowedUDPPortRanges = [{ from = 1716; to = 1764; }];
    };
    programs = {
      firefox.nativeMessagingHosts.gsconnect = true;
      dconf = enabled; # must have. DB for storing GNOME related settings
      gnome-terminal = enabled; # must have. allow better integration with terminals
    };
    # Enable the corresponding configuration at the user level.
    # run "dconf watch /" and change settings to see the changes live
    snowfallorg.users.roey.home.config.dconf.settings = {
      # TODO: maybe there is a more generic way of doing these
      "org/gnome/desktop/input-sources" = {
        per-window = true;
        sources = [ (mkTuple [ "xkb" "us" ]) (mkTuple [ "xkb" "il" ]) ];
      };
      "org/gnome/desktop/default-applications/terminal".exec = "alacritty";
      "org/gnome" = {
        Terminal = "alacritty";
      };
      "org/gnome/desktop/peripherals/touchpad".natural-scroll = false;
      "org/gnome/desktop/peripherals/mouse".natural-scroll = false;
      # keyboard shortcuts
      "org/gnome/settings-daemon/plugins/media-keys" = {
        www = [ "<Super>b" ];
        home = [ "<Super>e" ];
        terminal = [ "<Super>f" ];
        console = [ "<Super>f" ];
        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        ];
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
        name = "open-terminal";
        command = "gnome-terminal --maximize --name terminal";
        # command = config.snowfallorg.users.roey.home.config.home.sessionVariables.TERMINAL;
        binding = "<Super>Return";
      };
      "org/gnome/desktop/peripherals/touchpad".click-method = "areas"; # allow right click in touchpad



      # GNOME specific settings
      "org/gnome/desktop/interface".show-battery-percentage = true;
      "org/gnome/shell" = {
        enabled-extensions = with pkgs.gnomeExtensions; [
          user-themes.extensionUuid
          dash-to-dock.extensionUuid
          # noannoyance.extensionUuid
          caffeine.extensionUuid
          clipboard-indicator.extensionUuid
          gsconnect.extensionUuid
          unite.extensionUuid
          dexcom-cgm-monitor.extensionUuid
        ];
      };
      "org/gnome/mutter" = {
        experimental-features = [
          "scale-monitor-framebuffer" # Enables fractional scaling (125% 150% 175%)
          "variable-refresh-rate" # Enables Variable Refresh Rate (VRR) on compatible displays
          "xwayland-native-scaling" # Scales Xwayland applications to look crisp on HiDPI screens
        ];
      };
      "org/gnome/mutter" = {
        workspaces-only-on-primary = false;
        center-new-windows = true;
        edge-tiling = false; # Tiling
      };
      # GNOME extentions related
      "org/gnome/shell/keybindings" = {
        "toggle-message-tray" = [ ]; # Super+v by default
      };
      "org/gnome/shell/extensions/clipboard-indicator" = {
        "toggle-menu" = [ "<Super>v" ];
        "paste-button" = false;
        "paste-on-select" = true;
        "history-size" = 1000;
        "move-item-first" = true;
      };
      "org/gnome/shell/extensions/dexcom" = {
        "region" = "Non-US";
        "show-icon" = false;
        "show-delta" = false;
        "ulrgent-high-threshold" = 180;
        "high-threshold" = 130;
        "low-threshold" = 80;
        "urgent-low-threshold" = 55;
      };
      "org/gnome/shell/extensions/caffeine" = {
        "show-notifications" = false;
        "show-indicator" = "never";
        "enable-mpris" = true;
      };
    };
  };
}
