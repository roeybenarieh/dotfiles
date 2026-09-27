{ system, namespace, inputs, lib, config, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.omnigent;
in
{
  options.${namespace}.omnigent = with types; {
    enable = mkBoolOpt false "Enable Omnigent, the multi-agent coding CLI/meta-harness (orchestrates Claude Code, Codex, Cursor, and others) with its local web console.";
    noAutoOpenBrowser = mkBoolOpt false "Suppress the automatic browser tab opened by `omnigent start` / `omni host` (sets OMNIGENT_HOST_NO_OPEN=1) and by `omnigent run` per conversation (sets auto_open_conversation=false in ~/.omnigent/config.yaml).";
  };

  config = mkIf cfg.enable (
    let
      omnigent = inputs.llm-agents-nix.packages.${system}.omnigent;
    in
    {
      home.packages = [ omnigent ];

      # Route `claude`/`codex` through Omnigent's harness selection instead of
      # invoking the underlying CLIs directly. `omni codex` forwards
      # unrecognized args straight through to Codex, so it can carry the same
      # per-directory trust override as extra.codex's own `codex` alias
      # (config.toml is a read-only Nix store symlink, so this can't be
      # persisted and must be injected on every invocation instead).
      # `mkForce` wins over extra.codex's alias when both modules are enabled.
      home.shellAliases = {
        claude = "omni claude";
        codex = mkForce ''omni codex -c "projects.\"$(pwd)\"={trust_level=\"trusted\"}"'';
      };

      home.sessionVariables = {
        DO_NOT_TRACK = "1";
      } // optionalAttrs cfg.noAutoOpenBrowser {
        # Only suppresses the browser tab opened by `omnigent start` / `omni host`
        # for the host web UI. `omnigent run`'s per-conversation auto-open is a
        # separate code path gated by the `auto_open_conversation` key in
        # ~/.omnigent/config.yaml, with no environment-variable override — hence
        # the activation script below.
        OMNIGENT_HOST_NO_OPEN = "1";
      };

      # `omnigent run` defaults to opening a browser tab per conversation and is
      # only controllable via ~/.omnigent/config.yaml (no env var), so persist
      # the setting through the CLI's own config writer to avoid clobbering any
      # other keys (default_agent, harness, auth, ...) already in that file.
      home.activation.omnigentNoAutoOpenConversation = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${omnigent}/bin/omnigent config set --global \
          auto_open_conversation=${if cfg.noAutoOpenBrowser then "false" else "true"}
      '';
    }
  );
}
