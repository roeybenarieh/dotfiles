{
  description = "Roey Ben Arieh user home configuration";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"; # unstable
    nixpkgs-stable.url = "github:NixOS/nixpkgs/master"; # stable
    home-manager = {
      url = "github:nix-community/home-manager/master"; # unstable
      inputs.nixpkgs.follows = "nixpkgs";
    };
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, nixpkgs-stable, home-manager, firefox-addons, ... }@inputs:
    let
      pkgs = nixpkgs.legacyPackages."x86_64-linux";
      pkgs-stable = nixpkgs-stable.legacyPackages."x86_64-linux";
    in {
      homeConfigurations = {
        roey = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit pkgs-stable;
            inherit inputs;
          };
          modules = [ ./.config/home-manager/home.nix ];
        };
      };

      nixosConfigurations = {
        roey-nixos = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit pkgs-stable; };
          modules = [ ./nix/hosts/roey-nixos ];
        };
      };
    };
}
