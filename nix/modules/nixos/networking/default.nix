{ pkgs, namespace, lib, config, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.networking;
  lastResortConnection = { method = "auto"; "route-metric" = 1000; };
  phoneMac = "28:02:2e:8a:cb:1a";
  phoneWifiPassword = "sisma111";
  phoneMacUnderscored = builtins.replaceStrings [ ":" ] [ "_" ] phoneMac;
in
{
  options.${namespace}.networking = with types; {
    enable = mkBoolOpt false "Whether or not to enable networking using NetworkManager.";
    hostName = mkstrOpt nil "Hostname of the machine";
    hotspotName = mkstrOpt "${cfg.hostName}-hotspot" "The name of the machine Hotspot";
  };

  config = mkIf cfg.enable {
    # Disable blueman's ConnectionNotifier plugin so it never fires connect/disconnect
    # notifications (the iPhone tether auto-connects/disconnects frequently).
    # "!PluginName" is blueman's convention for a user-disabled plugin (see PluginManager.py).
    snowfallorg.users.roey.home.config.dconf.settings = {
      "org/blueman/general".plugin-list = [ "!ConnectionNotifier" ];
    };

    environment.systemPackages = with pkgs; [ openfortivpn nmgui ];
    programs.localsend = enabled;
    networking = {
      inherit (cfg) hostName; # Define your hostname.
      networkmanager = {
        enable = true;
        # NOTE: when changing/deleting/adding profiles, you must manually delete the leftover connections
        ensureProfiles.profiles = {
          # NOTE: if you want to check the network usage of each interface, run:
          # watch -n1 'ip -s link show enp0s13f0u1u3; ip -s link show wlan0'
          "Wired" = {
            connection = {
              id = "Wired";
              type = "802-3-ethernet";
              autoconnect = true;
              # Higher priority than NM's auto-created "Wired connection 1" (which gets -999)
              autoconnect-priority = 100;
            };
            ipv4 = { method = "auto"; "route-metric" = 10; };
            ipv6 = { method = "auto"; "route-metric" = 10; };
          };

          "Jutomate FortiVPN" = {
            connection = {
              id = "Jutomate FortiVPN";
              type = "vpn";
              autoconnect = false;
            };
            vpn = {
              service-type = "org.freedesktop.NetworkManager.fortisslvpn";
              gateway = "149.106.132.26:10443";
              user = "roey";
              trusted-cert = "30a034feac05b7cfdf3d758e1dd359649ddb6d4e84b96031e619c6a90b1f207f";
            };
          };
          # NOTE: this connection work automatically in Iphone only if there is an automation that toogle off and on the hotspot every time you want to start using it.
          "RoeyBA Iphone" = {
            connection = {
              id = "RoeyBA Iphone";
              type = "wifi";
              autoconnect = true;
            };
            wifi = {
              ssid = "RoeyBA Iphone";
              mode = "infrastructure";
              hidden = true; # iOS suppresses hotspot beacons; active probing is required to find it
            };
            wifi-security = {
              key-mgmt = "wpa-psk";
              psk = phoneWifiPassword;
            };
            ipv4 = { method = "auto"; "route-metric" = 600; "never-default" = true; };
            ipv6 = { method = "auto"; "route-metric" = 600; "never-default" = true; };
          };

          # NOTE: this connection must be configured manually at first time via bluejay
          "RoeyBA Iphone BT" = {
            connection = {
              id = "RoeyBA Iphone BT";
              type = "bluetooth";
              autoconnect = true;
            };
            bluetooth = {
              bdaddr = phoneMac;
              type = "panu";
            };
            ipv4 = { method = "auto"; "route-metric" = 1000; "never-default" = true; };
            ipv6 = { method = "auto"; "route-metric" = 1000; "never-default" = true; };
          };
        };
        plugins = [ pkgs.networkmanager-fortisslvpn ];
      };

      localCommands = ''
        # set all known connections(by name) to be autoconnected 
        for name in $(${pkgs.networkmanager}/bin/nmcli -t -f NAME connection show); do
          ${pkgs.networkmanager}/bin/nmcli connection modify \"$name\" connection.autoconnect yes || true
        done
      '';

      # wifi related
      networkmanager.wifi.backend = "iwd";
      wireless.iwd = {
        enable = true; # better than wpa_supplicant that is used by default
        settings = {
          # NM manages autoconnect; iwd must not compete with it
          Settings.AutoConnect = false;
          # Scan aggressively so hidden iPhone hotspot is found quickly
          Scan = {
            DisablePeriodicScan = false;
            InitialPeriodicScanInterval = 10;
            MaximumPeriodicScanInterval = 30;
          };
        };
      };
    };
  };
}
