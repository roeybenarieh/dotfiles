{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.software-development.languages.python;
in
{
  options.${namespace}.software-development.languages.python = with types; {
    enable = mkBoolOpt false "Whether or not to install python.";
    extraPackages = mkOption {
      type = listOf str;
      default = [ ];
      description = ''
        Extra python3Packages attribute names to merge into the single shared
        python environment. Home Manager can only have one python interpreter/withPackages
        closure on PATH at a time — two independent ones collide on
        bin/python3, bin/pip3, etc. — so other modules extend this one instead
        of installing their own.
      '';
    };
  };

  config = mkIf cfg.enable {
    # install python+pip
    home.packages = with pkgs; [
      (python314.withPackages (
        ps:
        (with ps; [
          pip
          fastapi
          pydantic
          requests
          pytest
        ])
        ++ map (name: ps.${name}) cfg.extraPackages
      ))
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
