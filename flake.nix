{
  description = "Roey Ben Arieh user home configuration";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"; # unstable
    nixpkgs-stable.url = "github:NixOS/nixpkgs/master";
    home-manager = {
      url = "github:nix-community/home-manager/master"; # unstable
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-stable, home-manager, ... }@inputs:
    let
      pkgs = nixpkgs.legacyPackages."x86_64-linux";
      pkgs-stable = nixpkgs-stable.legacyPackages."x86_64-linux";
    in {
      homeConfigurations = {
        # home config per user
        roey = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = { inherit pkgs-stable; };
          modules = [ ./.config/home-manager/home.nix ];
        };
      };
    };
}
