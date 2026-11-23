{
  description = "Roey Ben Arieh NixOS+HomeManager configurations";
  inputs = {
    # nixos-unstable only advances to commits Hydra has fully built, so every
    # package is in cache.nixos.org. `master` has no such guarantee and makes
    # packages like firefox or libreoffice compile locally.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    doh1-autofill = {
      url = "github:roeybenarieh/doh1-autofill/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spotify-adblock = {
      url = "github:abba23/spotify-adblock";
      flake = false;
    };
    injectify = {
      url = "github:shade-solutions/Injectify";
      flake = false;
    };
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
    claude-desktop = {
      url = "github:aaddrick/claude-desktop-debian";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ambxst = {
      url = "github:roeybenarieh/Ambxst";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprshell = {
      url = "github:H3rmt/hyprshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Provides `opencode`, `claude-code` and `codex`. Deliberately does NOT follow
    # our nixpkgs: its binary cache (cache.numtide.com, see nixos basic module)
    # is built against its own pinned nixpkgs, so following would force local builds.
    llm-agents-nix.url = "github:numtide/llm-agents.nix";
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
        claude-desktop.overlays.default
      ];

      # home manager modules
      homes.modules = with inputs; [
        stylix.homeModules.stylix
        spicetify-nix.homeManagerModules.default
        ambxst.homeManagerModules.default
        hyprshell.homeModules.default
      ];

      # nixos modules
      systems.modules.nixos = with inputs; [
        stylix.nixosModules.stylix
        home-manager.nixosModules.home-manager
        grub2-themes.nixosModules.default
        ambxst.nixosModules.default
      ];
    };
}
