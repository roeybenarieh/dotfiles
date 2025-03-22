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
      audio.enable = true;
      i18n.enable = true;
      apps.enable = true;
      desktop.enable = true;
      boot.enable = true;
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
    nix.settings.auto-optimise-store = true;


    # Enable CUPS to print documents.
    services.printing.enable = true;

  };
}
 
