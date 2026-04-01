{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.windows;
in
{
  options.${namespace}.windows = with types; {
    enable = mkBoolOpt false "Whether or not to enable support for windows apps.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      # bottles
      wine-staging
      winetricks
      powershell # windows powershell
      # winboat # easly run almost every windows application.(use VM underneath)
    ];
    home.shellAliases = { powershell = "pwsh"; };
  };
}
