{ namespace, lib, config, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.mcp;
in
{
  options.${namespace}.mcp = with types; {
    enable = mkBoolOpt false "Enable the shared MCP (Model Context Protocol) server registry, consumed by AI coding harnesses (Claude Code, Codex, ...) via their `enableMcpIntegration` option.";
  };

  config = mkIf cfg.enable {
    programs.mcp = {
      enable = true;

      servers = {
        context7 = {
          url = "https://mcp.context7.com/mcp?client=claude-code-nix";
        };
        headroom = {
          command = "uvx";
          args = [ "--from" "headroom-ai" "headroom" "mcp" "serve" ];
        };
        serena = {
          command = "uvx";
          args = [
            "--from"
            "git+https://github.com/oraios/serena"
            "serena"
            "start-mcp-server"
            "--project-from-cwd"
            "--context"
            "claude-code"
            "--open-web-dashboard"
            "False"
          ];
        };
      };
    };
  };
}
