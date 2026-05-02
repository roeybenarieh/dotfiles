{ pkgs, namespace, lib, config, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.networking;
  lastResortConnection = { method = "auto"; "route-metric" = 1000; };
in
{
  options.${namespace}.networking = with types; {
    enable = mkBoolOpt false "Whether or not to enable networking using NetworkManager.";
    hostName = mkstrOpt nil "Hostname of the machine";
    hotspotName = mkstrOpt "${cfg.hostName}-hotspot" "The name of the machine Hotspot";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ openfortivpn ];
    programs.localsend = enabled;
    networking = {
      inherit (cfg) hostName; # Define your hostname.
      networkmanager = {
        enable = true;
        ensureProfiles.profiles = {
          "jutomate-fortivpn" = {
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
          "phone-bt-tether" = {
            connection = {
              id = "RoeyBA Iphone Network";
              uuid = "1636e344-74a6-4e71-aeb7-e72e2696ace3";
              type = "bluetooth";
              autoconnect = true;
            };
            bluetooth = {
              bdaddr = "04:68:65:4D:6C:C1"; # my phone mac address
              type = "panu";
            };
            ipv4 = lastResortConnection;
            ipv6 = lastResortConnection // { "never-default" = true; }; # the never-default helps increase upload speeds when this connection is not good and a better one exists
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
          Settings.AutoConnect = true;
        };
      };
    };
  };
}
