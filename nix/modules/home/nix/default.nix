{ namespace, lib, config, pkgs, inputs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.nix;
in
{
  options.${namespace}.nix = with types; {
    enable = mkBoolOpt false "Whether or not to enable nix configuraiton.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ nix-tree ];

    # Pin the global registry to the flake input(so nix shell nixpkgs#... would use this flake's nixpkgs input)
    nix.registry.nixpkgs.flake = inputs.nixpkgs;
    # (Optional but recommended) Pin legacy NIX_PATH to match
    nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

    xdg.configFile = {
      "nix" = {
        source = ./nix;
        recursive = true;
      };
    };
  };
}
