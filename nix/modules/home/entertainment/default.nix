{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.entertainment;
in
{
  options.${namespace}.entertainment = with types; {
    enable = mkBoolOpt false "Whether or not to enable entertainment apps.";
  };

  config = mkIf cfg.enable {
    # TODO: for the love of god, when installing stremio make sure to disable caching!!!
    # from my experience it make stremio playing videos WAY MORE smoothly
    home.packages = with pkgs;[
      stremio # streaming app
      # TODO: find a better place for krita
      krita # GUI paint app
    ];
  };
}
