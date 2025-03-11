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
      (python311.withPackages (pkgs: with pkgs; [
        pip
        fastapi
        pydantic
        requests
        pytest
      ]))
    ];

    # poetry
    programs.poetry = {
      enable = true;
      package = pkgs.poetry;
    };
    xdg.configFile."pypoetry".source = {
      source = ../../../../.config/pypoetry;
      recursive = true;
    };

    # python configuration
    home.sessionVariables = {
      PYTHONASYNCIODEBUG = 1; # for debuging asyncio application
    };
    home.shellAliases = { python = "python3.11"; };
  };
}
