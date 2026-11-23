{ pkgs, ... }:

# OpenCode Manager CLI, pinned to the npm tarball (no runtime dependencies:
# dist/ bundles everything except the OpenCode-provided TUI peers).
# Output: bin/ocm (wrapped node entrypoint) and dist/ (the OpenCode TUI plugin).
let
  tarball = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@opencode-manager/ocm-cli/-/ocm-cli-0.4.1.tgz";
    hash = "sha512-vGxRkFKYeCpNWFXU7ChFezUnAWXG/CJePiEqS5XIYMG04mwH7zSuiTTae3vtnpZsqvu+3KItvRBq7zqVCkB/Og==";
  };
in
pkgs.runCommand "ocm-cli-0.4.1" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
  mkdir -p $out/bin
  tar xzf ${tarball} -C $out --strip-components=1
  makeWrapper ${pkgs.nodejs}/bin/node $out/bin/ocm --add-flags $out/dist/ocm.js
''
