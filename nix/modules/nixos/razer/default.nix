{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.razer;
in
{
  options.${namespace}.razer = with types; {
    enable = mkBoolOpt false "Whether or not to enable razer features.";
  };

  config = mkIf cfg.enable {
    hardware.openrazer = {
      enable = true;
      users = [ "roey" ];
    };
    environment.systemPackages = with pkgs; [
      polychromatic # openrazer UI
    ];
  };
}
