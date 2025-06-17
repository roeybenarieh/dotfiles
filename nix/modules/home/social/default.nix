{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.social;
in
{
  options.${namespace}.social = with types; {
    enable = mkBoolOpt false "Whether or not to enable social apps.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      discord
      zoom-us
      teams-for-linux
    ];
  };
}
