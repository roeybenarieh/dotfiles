{
  description = "Roey Ben Arieh user home configuration";
  inputs = {
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable"; # unstable
    nixpkgs.url = "github:NixOS/nixpkgs/master"; # stable
    home-manager = {
      url = "github:nix-community/home-manager/master"; # unstable
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix.url = "github:danth/stylix";
  };

  outputs =
    { self, nixpkgs, nixpkgs-unstable, home-manager, nur, stylix, ... }@inputs:
    let
      pkgs = nixpkgs.legacyPackages."x86_64-linux";
      pkgs-unstable = nixpkgs-unstable.legacyPackages."x86_64-linux";
    in
    {
      homeConfigurations = {
        roey = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit pkgs-unstable;
            inherit inputs;
          };
          modules = [
            ./.config/home-manager/home.nix
            stylix.homeManagerModules.stylix
          ];
        };
      };

      nixosConfigurations = {
        roey-nixos = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit pkgs-unstable;
            inherit inputs;
          };
          modules = [ ./nix/hosts/roey-nixos ];
        };
      };
    };
}
