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
      security.enable = true;
      boot.enable = true;
      networking.enable = true;
    };

    # Define a user account. Don't forget to set a password with ‘passwd’.
    programs.zsh = enabled;
    users.users.roey = {
      isNormalUser = true;
      description = "roey";
      extraGroups = [
        "networkmanager"
        "wheel" # Enable ‘sudo’ for the user.
        "docker"
        "k3s"
        "libvirtd" # for using libvirtd VM technology
        "input" # permission to access input devices
      ];
      shell = pkgs.zsh;
    };

    # Perform garbage collection weekly to maintain low disk usage
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 1m"; # older than 1 month
    };

    services.ttyd = {
      enable = true;
      writeable = true;
      port = 7681;
    };

    # change screen's colour temperature at night
    services.redshift = {
      enable = true;
      extraOptions = [ "-m vidmode" ];
    };
    services.geoclue2 = enabled;
    location.provider = "geoclue2";

    # Optimize storage
    # You can also manually optimize the store via:
    #    nix-store --optimise
    # Refer to the following link for more details:
    # https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-auto-optimise-store
    nix = {
      settings.auto-optimise-store = true;
      optimise.automatic = true;
    };


    # Enable CUPS to print documents.
    services.printing.enable = true;

    # enable trash support in Nutils file explorer
    services.gvfs.enable = true;

    # enable dynamicly linked executables
    programs.nix-ld.enable = true;

    # enable numlock on start up
    services.xserver.displayManager.setupCommands = ''${getExe pkgs.numlockx} on'';
  };
}
 
