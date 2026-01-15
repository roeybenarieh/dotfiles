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
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    doh1-autofill = {
      url = "github:roeybenarieh/doh1-autofill/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    flake-programs-sqlite.url = "github:wamserma/flake-programs-sqlite";
    flake-programs-sqlite.inputs.nixpkgs.follows = "nixpkgs";
    grub2-themes = {
      url = "github:vinceliuice/grub2-themes";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # grafana dashboards
    grafana-dashboards = {
      url = "gitlab:gitlab-org/grafana-dashboards";
      flake = false;
    };
  };

  outputs = inputs:
    # snowfall lib extended funciton for flake-utils-plus
    inputs.snowfall-lib.mkFlake {
      # must have Snowfall arguments.
      inputs = inputs // { assets = ./assets; };
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

      # home manager modules
      homes.modules = with inputs; [
        stylix.homeModules.stylix
        spicetify-nix.homeManagerModules.default
      ];

      # nixos modules
      systems.modules.nixos = with inputs; [
        stylix.nixosModules.stylix
        home-manager.nixosModules.home-manager
        grub2-themes.nixosModules.default
      ];
    };
}
