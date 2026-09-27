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

    # config.toml is a read-only Nix store symlink under Home Manager, so
    # Codex can never persist a directory-trust decision itself (fails with
    # "failed to persist config"). Sidestep persistence entirely: inject
    # trust for the current directory as a one-off `-c` override on every
    # invocation instead, so it applies in-memory per run rather than being
    # written to disk.
    home.shellAliases.codex = ''codex -c "projects.\"$(pwd)\"={trust_level=\"trusted\"}"'';
  };
}
