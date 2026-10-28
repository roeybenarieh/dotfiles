{ namespace, lib, config, pkgs, inputs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.codex;

  # Codex CLI's native `notify` mechanism (config.toml root key): an argv
  # command Codex invokes on lifecycle events, appending a JSON payload as
  # the final argument. Currently the only event it fires is
  # "agent-turn-complete", i.e. Codex has stopped and control is back with
  # the user — the Codex analogue of Claude Code's Notification hook. This
  # wrapper pulls the final assistant message out of that payload and hands
  # it to the same desktop-notification-with-click-to-focus binary Claude
  # Code uses.
  codexNotifyScript = pkgs.writeShellApplication {
    name = "codex-notify";
    runtimeInputs = [ pkgs.jq pkgs.extra.notify-send-focus ];
    text = ''
      payload="$1"

      type=$(printf '%s' "$payload" | jq -r '.type // empty')
      [ "$type" = "agent-turn-complete" ] || exit 0

      msg=$(printf '%s' "$payload" | jq -r '.["last-assistant-message"] // "Codex needs your attention"')

      notify-send-focus -u normal "Codex" "$msg"
    '';
  };

  # config.toml is a read-only Nix store symlink under Home Manager, so
  # Codex can never persist a directory-trust decision itself (fails with
  # "failed to persist config"). Sidestep persistence entirely by patching
  # the real `codex` binary in place: rename it to `.codex-unwrapped` inside
  # the same package output and put a wrapper script at `bin/codex` that
  # injects a one-off `-c` trust override before exec-ing it. Since this
  # patched package becomes `programs.codex.package`, there is only ever one
  # `codex` on PATH — no shell alias, and no second executable that a
  # non-interactive/non-Home-Manager shell might skip.
  # ponytail: pushes the agent toward the simplest, dependency-light solution
  # (YAGNI, stdlib-first) instead of over-engineering. Installed as a real
  # Codex plugin (not just its skills) so its lifecycle hooks (claude-codex-hooks.json)
  # fire — those are what actually force the ruleset into context on every
  # turn; the skills alone are only model-invoked on a description match.
  # Codex's `plugins` list (unlike Claude Code's attrset form) derives the
  # plugin directory name from the derivation itself, and must match the
  # "name" field in .codex-plugin/plugin.json ("ponytail"), hence the
  # explicit `name =` override below.
  ponytailSrc = pkgs.fetchFromGitHub {
    name = "ponytail";
    owner = "dietrichgebert";
    repo = "ponytail";
    rev = "e3ba2aa6f1e6f0bc4d69eb09c9f0d0a93af56156";
    hash = "sha256-PES5XrSYx0VBXWVHEDRykGy0SAmJfV/luzy8Gfg0aAQ=";
  };

  codexPackage = pkgs.symlinkJoin {
    name = "codex-${pkgs.codex.version}";
    version = pkgs.codex.version;
    paths = [ pkgs.codex ];
    postBuild = ''
      mv "$out/bin/codex" "$out/bin/.codex-unwrapped"
      cat > "$out/bin/codex" <<WRAPPER
      #!/usr/bin/env bash
      exec "$out/bin/.codex-unwrapped" -c "projects.\"\$(pwd)\"={trust_level=\"trusted\"}" "\$@"
      WRAPPER
      chmod +x "$out/bin/codex"
    '';
  };
in
{
  options.${namespace}.codex = with types; {
    enable = mkBoolOpt false "Whether or not to enable Codex, the OpenAI coding agent CLI.";
  };

  config = mkIf cfg.enable {
    programs.codex = {
      enable = true;
      package = codexPackage;

      # Server list comes from `extra.mcp` (programs.mcp.servers) — see
      # nix/modules/home/ai/mcp/default.nix.
      enableMcpIntegration = true;

      settings.notify = [ "${codexNotifyScript}/bin/codex-notify" ];

      plugins = [ ponytailSrc ];
    };

    # Home Manager links config.toml as a read-only symlink into the Nix
    # store. That's fine for Codex's own CLI here (codexPackage above
    # sidesteps writing to it at all, via the in-memory `-c` override), but
    # other tools that stage a working *copy* of this file — notably
    # Omnigent's codex-native bridge, which copies it into a fresh
    # per-session codex-home and then tries to write a trust entry into
    # *that* copy — inherit the store file's read-only mode on the copy and
    # crash with `PermissionError: [Errno 13] Permission denied`. Convert
    # the managed symlink into a real, writable file after every activation
    # so anything that copies it starts from normal permissions, and clean
    # it back up before the next `linkGeneration` so Home Manager can still
    # re-link it — the same pattern (and reason) as the upstream
    # `cleanCodexPluginCache` activation script: HM won't overwrite a real
    # file sitting where it expects to place its own symlink.
    home.activation.codexRemoveWritableConfig =
      inputs.home-manager.lib.hm.dag.entryBefore [ "linkGeneration" ]
        ''
          configPath="$HOME/.codex/config.toml"
          if [ -f "$configPath" ] && [ ! -L "$configPath" ]; then
            rm -f "$configPath"
          fi
        '';
    home.activation.codexWritableConfig =
      inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ]
        ''
          configPath="$HOME/.codex/config.toml"
          if [ -L "$configPath" ]; then
            storePath=$(readlink -f "$configPath")
            rm -f "$configPath"
            install -m644 "$storePath" "$configPath"
          fi
        '';
  };
}
