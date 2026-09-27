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

      # Server list comes from `extra.mcp` (programs.mcp.servers) — see
      # nix/modules/home/ai/mcp/default.nix.
      enableMcpIntegration = true;
    };
  };
}
