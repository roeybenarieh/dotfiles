{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.tor;
in
{
  options.${namespace}.tor = with types; {
    enable = mkBoolOpt false "Whether or not to install tor browser.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ tor-browser ];
  };
}
