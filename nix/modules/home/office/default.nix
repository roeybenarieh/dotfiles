{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.office;
in
{
  options.${namespace}.office = with types; {
    enable = mkBoolOpt false "Whether or not to enable support office documents and editors.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      onlyoffice-bin
    ];
  };
}
