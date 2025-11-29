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
    networking = {
      inherit (cfg) hostName; # Define your hostname.
      networkmanager = {
        enable = true;
        # networking.networkmanager.ensureProfiles
        dispatcherScripts = [
          {
            # for viewing logs: "journalctl -f | grep AutoHotspot"
            type = "pre-up";
            source = pkgs.writeShellScript "autohotspot" ''
              #!/usr/bin/env bash
              # Dispatcher arguments:
              IFACE="$1" # $1 = interface name
              STATUS="$2" # $2 = status (up|down)
              # Hotspot connection profile name
              HOTSPOT_CONN="AutoHotspot"

              # Get interface type
              # FIX: this doesn't work, I can't get the interface type
              sleep 5 # HACK: wait for the interface to be up, only that its possible to get its type
              TYPE=$(nmcli -g GENERAL.TYPE device show "$IFACE" 2>/dev/null)
              TYPE=$(nmcli -g GENERAL.TYPE device show "$IFACE" 2>/dev/null)

              logger "AutoHotspot: 1"
              logger "AutoHotspot: $IFACE"
              logger "AutoHotspot: $STATUS"
              logger "AutoHotspot: $TYPE"
              logger "AutoHotspot: $CONNECTION_ID"
              logger "AutoHotspot: --------------------------"
              # Only act on Ethernet interfaces
              if [ "$TYPE" != "ethernet" ]; then
              	exit 0
              fi

              logger "AutoHotspot: 2"
              # When ethernet goes UP → start hotspot
              if [ "$STATUS" = "up" ]; then

              	logger "AutoHotspot: Ethernet up, starting hotspot"
              	nmcli connection up "$HOTSPOT_CONN"
              fi

              # When ethernet goes DOWN → stop hotspot
              if [ "$STATUS" = "down" ]; then
              	logger "AutoHotspot: Ethernet down, stopping hotspot."
              	nmcli connection down "$HOTSPOT_CONN"
              fi
            '';
          }
        ];
        ensureProfiles.profiles = {
          autoHotspot = {
            connection = {
              id = cfg.hotspotName;
              type = "wifi";
              autoconnect = false; # Do NOT auto-connect(only connect using the dispatcher script)
            };
            wifi-security = {
              auth-alg = "open";
              key-mgmt = "wpa-psk"; # wpa-psk, sae, wpa-eap, 
              psk = "${cfg.hotspotName}123";
            };
            wifi = {
              mode = "ap"; # Access point mode
              ssid = cfg.hotspotName; # Hotspot name
            };
            # NAT + DHCP for hotspot clients
            ipv4.method = "shared";
            ipv6.method = "shared";
          };
        };
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
