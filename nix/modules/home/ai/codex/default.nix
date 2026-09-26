{ namespace, lib, config, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.codex;
in
{
  options.${namespace}.codex = with types; {
    enable = mkBoolOpt false "Whether or not to enable Codex, the OpenAI coding agent CLI.";
  };

  config = mkIf cfg.enable {
    programs.codex = {
      enable = true;
    };
  };
}
