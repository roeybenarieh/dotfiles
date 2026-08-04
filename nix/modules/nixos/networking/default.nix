{ pkgs, namespace, lib, config, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.networking;
  phoneMac = "28:02:2e:8a:cb:1a";
  phoneWifiPassword = "sisma111";
  phoneMacUnderscored = builtins.replaceStrings [ ":" ] [ "_" ] phoneMac;
  metricEthernet = 10;
  metricIphoneWifi = 600;
  metricIphoneBt = 1000;
  nameIphoneWifi = "RoeyBA Iphone";
  nameIphoneBt = "RoeyBA Iphone BT";
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
            ipv4 = { method = "auto"; "route-metric" = metricEthernet; };
            ipv6 = { method = "auto"; "route-metric" = metricEthernet; };
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
          ${nameIphoneWifi} = {
            connection = {
              id = nameIphoneWifi;
              type = "wifi";
              autoconnect = true;
            };
            wifi = {
              ssid = nameIphoneWifi;
              mode = "infrastructure";
              hidden = true; # iOS suppresses hotspot beacons; active probing is required to find it
            };
            wifi-security = {
              key-mgmt = "wpa-psk";
              psk = phoneWifiPassword;
            };
            # never-default: NM must not install a default route for iPhone on its own.
            # The dispatcher script below injects one only when ethernet is explicitly down.
            ipv4 = { method = "auto"; "route-metric" = metricIphoneWifi; "never-default" = true; };
            ipv6 = { method = "auto"; "route-metric" = metricIphoneWifi; "never-default" = true; };
          };

          # NOTE: this connection must be configured manually at first time via bluejay
          ${nameIphoneBt} = {
            connection = {
              id = nameIphoneBt;
              type = "bluetooth";
              autoconnect = true;
            };
            bluetooth = {
              bdaddr = phoneMac;
              type = "panu";
            };
            ipv4 = { method = "auto"; "route-metric" = metricIphoneBt; "never-default" = true; };
            ipv6 = { method = "auto"; "route-metric" = metricIphoneBt; "never-default" = true; };
          };
        };
        plugins = [ pkgs.networkmanager-fortisslvpn ];
        dispatcherScripts = [
          {
            source = pkgs.writeShellScript "iphone-default-route" ''
              IFACE="$1"
              ACTION="$2"

              [[ "$ACTION" == "up" || "$ACTION" == "down" || "$ACTION" == "dhcp4-change" || "$ACTION" == "dhcp6-change" ]] || exit 0

              # NM dispatcher runs with an empty PATH — use full store paths for every binary.
              nmcli="${pkgs.networkmanager}/bin/nmcli"
              ip="${pkgs.iproute2}/bin/ip"
              awk="${pkgs.gawk}/bin/awk"
              grep="${pkgs.gnugrep}/bin/grep"

              # Get the kernel IP interface for a named NM connection.
              # Uses connection name instead of parsing device status to avoid the BT MAC
              # address (28:02:2E:8A:CB:1A) breaking colon-delimited parsing.
              get_ip_iface() {
                "$nmcli" -t -f GENERAL.IP-IFACE connection show "$1" 2>/dev/null \
                  | "$awk" -F: 'NR==1 {print $2}'
              }

              # NM never stores the gateway when never-default=true, so derive it:
              # first host address in the interface's link-local subnet (e.g. 172.20.10.0/28 → 172.20.10.1).
              get_ipv4_gateway() {
                local subnet network
                subnet=$("$ip" -4 route show dev "$1" scope link 2>/dev/null | "$awk" 'NR==1 {print $1}')
                [[ -z "$subnet" ]] && return
                network="''${subnet%/*}"
                IFS=. read -r a b c d <<< "$network"
                echo "$a.$b.$c.$((d + 1))"
              }

              get_ipv6_gateway() {
                "$ip" -6 neigh show dev "$1" nud reachable nud stale 2>/dev/null \
                  | "$awk" 'NR==1 {print $1}'
              }

              # True when at least one ethernet device is in NM "connected" state.
              is_ethernet_connected() {
                "$nmcli" -t -f TYPE,STATE device 2>/dev/null | "$grep" -q "^ethernet:connected"
              }

              declare -A iphone_metric=(
                ["${nameIphoneWifi}"]=${toString metricIphoneWifi}
                ["${nameIphoneBt}"]=${toString metricIphoneBt}
              )

              add_iphone_routes() {
                for conn in "''${!iphone_metric[@]}"; do
                  dev=$(get_ip_iface "$conn")
                  [[ -z "$dev" ]] && continue
                  metric=''${iphone_metric[$conn]}
                  gw4=$(get_ipv4_gateway "$dev")
                  [[ -n "$gw4" ]] \
                    && "$ip" -4 route replace default via "$gw4" dev "$dev" metric "$metric" 2>/dev/null || true
                  gw6=$(get_ipv6_gateway "$dev")
                  [[ -n "$gw6" ]] \
                    && "$ip" -6 route replace default via "$gw6" dev "$dev" metric "$metric" 2>/dev/null || true
                done
              }

              remove_iphone_routes() {
                for conn in "''${!iphone_metric[@]}"; do
                  dev=$(get_ip_iface "$conn")
                  [[ -z "$dev" ]] && continue
                  "$ip" -4 route del default dev "$dev" 2>/dev/null || true
                  "$ip" -6 route del default dev "$dev" 2>/dev/null || true
                done
              }

              iface_type=$("$nmcli" -t -f GENERAL.TYPE device show "$IFACE" 2>/dev/null \
                | "$awk" -F: 'NR==1 {print $2}')

              if [[ "$iface_type" == "ethernet" ]]; then
                if [[ "$ACTION" == "down" ]]; then
                  add_iphone_routes
                elif [[ "$ACTION" == "up" || "$ACTION" == "dhcp4-change" ]]; then
                  remove_iphone_routes
                fi
              elif [[ "$ACTION" == "up" || "$ACTION" == "dhcp4-change" || "$ACTION" == "dhcp6-change" ]]; then
                # iPhone (or BT) got a new IP. Add default routes only when ethernet
                # is not currently connected — this covers both the "never plugged in at
                # boot" case and the "ethernet went down at runtime" case without needing
                # a flag file.
                if ! is_ethernet_connected; then
                  add_iphone_routes
                fi
              fi
            '';
            type = "basic";
          }
        ];
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
