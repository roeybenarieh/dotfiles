{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.vscode;
in
{
  options.${namespace}.vscode = with types; {
    enable = mkBoolOpt false "Whether or not to enable vscode.";
  };

  config = mkIf cfg.enable {
    programs.vscode = {
      enable = true;
      profiles.default.extensions = with pkgs.vscode-extensions; [
        ms-python.python # microsoft python extension
        esbenp.prettier-vscode # prettier formatter
        charliermarsh.ruff # python ruff linter
        ms-azuretools.vscode-docker # docker
      ];
    };
  };
}
