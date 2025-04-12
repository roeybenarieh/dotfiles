{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.nix;
in
{
  options.${namespace}.nix = with types; {
    enable = mkBoolOpt false "Whether or not to enable nix configuraiton.";
  };

  config = mkIf cfg.enable {
    xdg.configFile = {
      "nix" = {
        source = ./nix;
        recursive = true;
      };
    };
  };
}
