{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.opencode;
in
{
  options.${namespace}.opencode = {
    enable = mkBoolOpt false "Whether or not to enable OpenCode.";
  };

  config = mkIf cfg.enable {
    programs.opencode = {
      enable = true;
      enableMcpIntegration = true;
      settings = {
        # Community Claude Pro/Max OAuth support for OpenCode v1.
        # Sign in with /connect -> Anthropic -> Claude Pro/Max.
        plugin = [ "@ex-machina/opencode-anthropic-auth@1.8.5" ];
        # Authenticate with `opencode auth login --provider openai`, choosing ChatGPT.
        model = "openai/gpt-5.4";
      };
    };

    # Required by the OpenCode Neovim plugin.
    programs.neovim.extraPackages = [ pkgs.lsof ];
  };
}
