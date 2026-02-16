{ pkgs, namespace, lib, config, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.networking;
in
{
  options.${namespace}.networking = with types; {
    enable = mkBoolOpt false "Whether or not to enable networking using NetworkManager.";
    hostName = mkstrOpt nil "Hostname of the machine";
    hotspotName = mkstrOpt "${cfg.hostName}-hotspot" "The name of the machine Hotspot";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ openfortivpn ];
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
