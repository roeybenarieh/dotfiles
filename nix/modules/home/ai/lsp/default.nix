{ namespace, lib, config, pkgs, inputs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.lsp;
  ai = config.${namespace};

  # One registry for native LSP clients and the shared Serena MCP backend.
  servers = {
    python = {
      package = pkgs.pyright;
      command = "${pkgs.pyright}/bin/pyright-langserver";
      args = [ "--stdio" ];
      extensions = [ ".py" ".pyi" ];
      opencodeId = "pyright";
    };
    lua = {
      package = pkgs.lua-language-server;
      command = "${pkgs.lua-language-server}/bin/lua-language-server";
      args = [ ];
      extensions = [ ".lua" ];
      opencodeId = "lua-ls";
    };
    nix = {
      package = pkgs.nixd;
      command = "${pkgs.nixd}/bin/nixd";
      args = [ ];
      extensions = [ ".nix" ];
      opencodeId = "nixd";
    };
  };

  # Serena's Lua backend discovers its executable on PATH. Python and Nix
  # support explicit launch commands through ls_specific_settings.
  serenaSettings = pkgs.writeText "serena-shared-lsp.json" (builtins.toJSON (
    mapAttrs (_: server: {
      ls_path = server.command;
      ls_args = server.args;
    }) (removeAttrs servers [ "lua" ])
  ));
  yamlPython = pkgs.python3.withPackages (ps: [ ps.ruamel-yaml ]);
  configureSerena = pkgs.writeText "configure-serena-lsp.py" ''
    import json
    import os
    from pathlib import Path
    import sys
    import tempfile
    from ruamel.yaml import YAML

    path = Path(sys.argv[1])
    yaml = YAML()
    yaml.preserve_quotes = True
    data = yaml.load(path) if path.exists() else {}
    if data is None:
        data = {}
    settings = data.setdefault("ls_specific_settings", {})
    desired = json.loads(Path(sys.argv[2]).read_text())
    for language, values in desired.items():
        settings.setdefault(language, {}).update(values)
    # Keep Serena's writable project registry, comments, and other settings.
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as output:
        temporary = Path(output.name)
        yaml.dump(data, output)
    os.replace(temporary, path)
  '';
in
{
  options.${namespace}.lsp.enable = mkBoolOpt
    (ai.claude.enable || ai.opencode.enable || ai.codex.enable || ai.mcp.enable)
    "Share Python, Lua, and Nix language servers across AI coding harnesses.";

  config = mkIf cfg.enable {
    home.packages = mapAttrsToList (_: server: server.package) servers;

    programs.claude-code.lspServers = mkIf ai.claude.enable (mapAttrs (language: server: {
      inherit (server) command args;
      extensionToLanguage = genAttrs server.extensions (_: language);
    }) servers);

    programs.opencode.settings.lsp = mkIf ai.opencode.enable (mapAttrs' (_: server:
      nameValuePair server.opencodeId {
        command = [ server.command ] ++ server.args;
        inherit (server) extensions;
      }
    ) servers);

    # Codex and other MCP clients use the existing shared Serena registration.
    # This also applies to Serena instances launched by Omnigent directly.
    home.activation.serenaSharedLsp = mkIf ai.mcp.enable (
      inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${yamlPython}/bin/python -I ${configureSerena} \
          "$HOME/.serena/serena_config.yml" ${serenaSettings}
      ''
    );
  };
}
