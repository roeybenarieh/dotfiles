{ namespace, lib, config, pkgs, inputs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.codex;

  # config.toml is a read-only Nix store symlink under Home Manager, so
  # Codex can never persist a directory-trust decision itself (fails with
  # "failed to persist config"). Sidestep persistence entirely by patching
  # the real `codex` binary in place: rename it to `.codex-unwrapped` inside
  # the same package output and put a wrapper script at `bin/codex` that
  # injects a one-off `-c` trust override before exec-ing it. Since this
  # patched package becomes `programs.codex.package`, there is only ever one
  # `codex` on PATH — no shell alias, and no second executable that a
  # non-interactive/non-Home-Manager shell might skip.
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
