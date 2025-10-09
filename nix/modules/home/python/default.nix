{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.python;
in
{
  options.${namespace}.python = with types; {
    enable = mkBoolOpt false "Whether or not to install python.";
  };

  config = mkIf cfg.enable {
    # install python+pip
    # home.packages = with pkgs; [ python312 python312Packages.pip ];
    home.packages = with pkgs; [
      (python312.withPackages (pkgs: with pkgs; [
        pip
        fastapi
        pydantic
        requests
        pytest
      ]))
    ];

    programs = {
      uv.enable = true;
      poetry.enable = true;
    };
    xdg.configFile."pypoetry" = {
      source = ./pypoetry;
      recursive = true;
    };

    # python configuration
    home.sessionVariables = {
      PYTHONASYNCIODEBUG = 1; # for debuging asyncio application
    };
  };
}
