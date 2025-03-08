{
  description = "Roey Ben Arieh NixOS+HomeManager configurations";
  inputs = {
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable"; # unstable
    nixpkgs.url = "github:NixOS/nixpkgs/master"; # stable
    home-manager = {
      url = "github:nix-community/home-manager/master"; # unstable
      inputs.nixpkgs.follows = "nixpkgs";
    };
    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix.url = "github:danth/stylix";
  };

  outputs = inputs:
    # snowfall lib extended funciton for flake-utils-plus
    inputs.snowfall-lib.mkFlake {
      # must have Snowfall arguments.
      inherit inputs;
      src = ./nix;

      # configure Snowfall Lib.
      snowfall = {
        namespace = "extra";
      };

      # channels config
      channels-config = {
        allowUnfree = true;
      };

      # overlays config
      overlays = with inputs; [
        nur.overlays.default
      ];
    };
}
