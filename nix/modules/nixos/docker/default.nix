{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.docker;
in
{
  options.${namespace}.docker = with types; {
    enable = mkBoolOpt false "Whether or not to enable docker.";
  };

  config = mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      enableOnBoot = false;
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };
  };
}
