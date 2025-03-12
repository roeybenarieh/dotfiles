{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.apps;
in
{
  options.${namespace}.apps = with types; {
    enable = mkBoolOpt false "Whether or not to enable system apps.";
  };

  config = mkIf cfg.enable {
    # disk partiations unitily
    programs.gnome-disks.enable = true;
  };
}
