{
  description = "Roey Ben Arieh user home configuration";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"; # unstable
    home-manager = {
      url = "github:nix-community/home-manager/master"; # unstable
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let pkgs = nixpkgs.legacyPackages."x86_64-linux";
    in {
      homeConfigurations = {
        # home config per user
        roey = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./.config/home-manager/home.nix ];
        };
      };
    };
}
