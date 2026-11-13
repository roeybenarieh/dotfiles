
{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.basic;
in
{
  options.${namespace}.basic = with types; {
    enable = mkBoolOpt true "Whether or not to enable basic configuration.";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      i18n.enable = true;
      security.enable = true;
      boot.enable = true;
      networking.enable = true;
      stylix.enable = true;
    };
    # use lix instaed of nix
    nixpkgs.overlays = [ (final: prev: {
      inherit (prev.lixPackageSets.stable)
        nixpkgs-review
        nix-eval-jobs
        nix-fast-build
        colmena;
    }) ];
    nix.package = pkgs.lixPackageSets.stable.lix;

    # Define a user account. Don't forget to set a password with ‘passwd’.
    programs.zsh = enabled;
    users.users = {
      remote = {
        isNormalUser = true;
        extraGroups = [
          "networkmanager"
          "wheel" # Enable ‘sudo’ for the user.
          "docker"
          "k3s"
        ];
        shell = pkgs.zsh;
      };
    };

    # Perform garbage collection weekly to maintain low disk usage
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 1m"; # older than 1 month
    };

    # Optimize storage
    # You can also manually optimize the store via:
    #    nix-store --optimise
    # Refer to the following link for more details:
    # https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-auto-optimise-store
    nix = {
      settings.auto-optimise-store = true;
      optimise.automatic = true;
    };

    # enable dynamicly linked executables
    programs.nix-ld.enable = true;
  };
}
