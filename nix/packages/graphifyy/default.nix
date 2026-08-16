{ pkgs, lib, inputs, ... }:
let
  python = pkgs.python312;
  src = pkgs.fetchFromGitHub {
    owner = "Graphify-Labs";
    repo = "graphify";
    rev = "09a34ad87a6c522757da1bfb8c2c209e523a4e55"; # v0.9.37
    hash = "sha256-uD6NEFL2ky5e60RKjl20+gYUHtMjABPoABmZ63vT/SM=";
  };
  workspace = inputs.uv2nix.lib.workspace.loadWorkspace { workspaceRoot = src; };
  overlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };
  pythonSet = (pkgs.callPackage inputs.pyproject-nix.build.packages { inherit python; })
    .overrideScope (lib.composeManyExtensions [
      inputs.pyproject-build-systems.overlays.default
      overlay
    ]);
  venv = pythonSet.mkVirtualEnv "graphify-env" workspace.deps.default;
  package = pkgs.runCommand "graphifyy" { } ''
    mkdir -p $out/bin
    ln -s ${venv}/bin/graphify $out/bin/graphify
    ln -s ${venv}/bin/graphify-mcp $out/bin/graphify-mcp
  '';
in
package // { inherit src; }
