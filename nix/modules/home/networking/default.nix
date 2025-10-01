{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.networking;
in
{
  options.${namespace}.networking = with types; {
    enable = mkBoolOpt false "Whether or not to enable networking related applications.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      curl
      wget
      postman
      remmina # rdp(and other protocols) client
    ];
    # ssh client
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks = {
        "*" = {
          user = "roey";
        };
        "roey.myddns.me" = {
          hostname = "roey.myddns.me";
          port = 48800;
        };
      };
    };
  };
}
