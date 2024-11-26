{ config, pkgs-stable, lib, ... }:

{
  # install python+pip
  # home.packages = with pkgs; [ python312 python312Packages.pip ];
  home.packages = with pkgs-stable; [
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
    package = pkgs-stable.poetry;
  };
  xdg.configFile."pypoetry/config.toml".source = ../../../../.config/pypoetry/config.toml;

  # python configuration
  home.sessionVariables = {
    PYTHONASYNCIODEBUG = 1; # for debuging asyncio application
  };
  home.shellAliases = { python = "python3.11"; };
}
