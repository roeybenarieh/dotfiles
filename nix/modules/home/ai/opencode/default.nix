{ namespace, lib, config, pkgs, inputs, ... }:
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
      # nixpkgs' 1.18.30 crashes during system-prompt assembly (upstream #50439).
      package = inputs.llm-agents-nix.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
      enableMcpIntegration = true;
      settings = {
        # Community Claude Pro/Max OAuth support for OpenCode v1.
        # Sign in with /connect -> Anthropic -> Claude Pro/Max.
        plugin = [ "@ex-machina/opencode-anthropic-auth@1.8.5" ];
        # Authenticate with `opencode auth login --provider openai`, choosing ChatGPT.
        model = "openai/gpt-6-astra";
      };
    };

    # Required by the OpenCode Neovim plugin.
    programs.neovim.extraPackages = [ pkgs.lsof ];
  };
}
