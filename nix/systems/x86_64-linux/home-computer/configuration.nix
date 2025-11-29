{ pkgs, namespace, lib, ... }:

with lib.${namespace};
{
  imports = [
    ./hardware-extra.nix
  ];

  ${namespace} = {
    apps = enabled;
    docker = enabled;
    gaming = enabled;
    gpu.nvidia1080ti = enabled;
    metrics.prometheus = enabled;
    rdp = enabled;
    ssh = enabled;
    razer = enabled;
    virtualization = enabled;
  };

  networking = {
    hostName = "home-computer"; # Define your hostname.
    networkmanager.enable = true; # Enable networking
    # TODO: make sure this is working
    # interfaces = {
    #   enp3s0 = {
    #     wakeOnLan = {
    #       enable = true;
    #     };
    #   };
    # };
  };
  # nix related
  nix.settings.experimental-features = [ "nix-command" "flakes" ];


  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
