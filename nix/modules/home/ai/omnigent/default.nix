{ system, namespace, inputs, lib, pkgs, config, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.omnigent;
in
{
  options.${namespace}.omnigent = with types; {
    enable = mkBoolOpt false "Enable Omnigent, the multi-agent coding CLI/meta-harness (orchestrates Claude Code, Codex, Cursor, and others) with its local web console.";
    noAutoOpenBrowser = mkBoolOpt false "Suppress the automatic browser tab opened by `omnigent start` / `omni host` (sets OMNIGENT_HOST_NO_OPEN=1) and by `omnigent run` per conversation (sets auto_open_conversation=false in ~/.omnigent/config.yaml).";

    tailscale = {
      enable = mkBoolOpt false "Make `omnigent start` / `omni start` (and `omnigent host --background` / `omni host --background`) transparently expose the local Omnigent server (default port 6767) to every device on your tailnet over HTTPS via `tailscale serve` (never `funnel` — this deliberately stays off the public internet), with Omnigent's trusted-origin/base-URL settings pointed at the resulting `https://<machine>.ts.net` address. The server itself keeps listening on 127.0.0.1 only — Tailscale Serve is the sole route in, so it's reachable from every device on your tailnet but never from the plain LAN. Requires `extra.tailscale.enable = true` and `extra.tailscale.operator` set to this user at the NixOS level. The connect URL is printed to the terminal on every `start`, since it depends on your tailnet's name and isn't known until you're logged in.";
    };
  };

  config = mkIf cfg.enable (
    let
      omnigentUnwrapped = inputs.llm-agents-nix.packages.${system}.omnigent;

      # Any command can auto-start the local server, so all invocations need
      # the trusted origin. Only explicit background starts configure Serve.
      tailscaleServeSetup = ''
        ts_host=$(${pkgs.tailscale}/bin/tailscale status --json | ${pkgs.jq}/bin/jq -r '.Self.DNSName // empty' | sed 's/\.$//') || ts_host=""
        if [[ -z "$ts_host" ]]; then
          if [[ "$should_serve" == 1 ]]; then
            echo "$0: tailscale isn't signed in yet -- run 'sudo tailscale up' first; starting without exposing it over your tailnet" >&2
          fi
        else
          export OMNIGENT_WS_ALLOWED_ORIGINS="https://$ts_host"
          export OMNIGENT_ACCOUNTS_BASE_URL="https://$ts_host"
          if [[ "$should_serve" == 1 ]]; then
            ${pkgs.tailscale}/bin/tailscale serve --bg --https=443 http://localhost:6767
            echo "Omnigent: reachable from any device on your tailnet at https://$ts_host" >&2
          fi
        fi
      '';

      mkOmnigentWrapper = name: pkgs.writeShellScriptBin name (''
        set -euo pipefail
      '' + optionalString cfg.tailscale.enable ''

        should_serve=0
        case "''${1:-}" in
          start) should_serve=1 ;;
          host)
            for arg in "$@"; do
              [[ "$arg" == "--background" ]] && should_serve=1
            done
            ;;
        esac
        ${tailscaleServeSetup}
      '' + ''

        exec ${omnigentUnwrapped}/bin/${name} "$@"
      '');

      omnigent =
        if cfg.tailscale.enable then
          pkgs.symlinkJoin {
            name = "omnigent-${omnigentUnwrapped.version or "wrapped"}";
            paths = [ (mkOmnigentWrapper "omnigent") (mkOmnigentWrapper "omni") ];
          }
        else
          omnigentUnwrapped;
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
        codex = "omni codex";
        opencode = "omni opencode";
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
