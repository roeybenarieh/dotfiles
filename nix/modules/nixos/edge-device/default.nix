{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.edge-device;
in
{
  options.${namespace}.edge-device = with types; {
    enable = mkBoolOpt false "Whether or not to enable edge-device (desktop/laptop) configuration.";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      audio.enable = true;
      apps.enable = true;
    };

    users.users = {
      roey = {
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
      remote.extraGroups = [
        "libvirtd" # for using libvirtd VM technology
        "input" # permission to access input devices
      ];
    };

    # change screen's colour temperature at night
    services.redshift = {
      enable = true;
      extraOptions = [ "-m vidmode" ];
    };
    services.geoclue2 = enabled;
    location.provider = "geoclue2";

    # Enable CUPS to print documents.
    services.printing.enable = true;

    # enable trash support in Nutils file explorer
    services.gvfs.enable = true;

    # enable numlock on start up
    services.xserver.displayManager.setupCommands = ''${getExe pkgs.numlockx} on'';

    # chromium restore tabs on startup
    programs.chromium.extraOpts = {
      "RestoreOnStartup" = 1;
    };
  };
}
