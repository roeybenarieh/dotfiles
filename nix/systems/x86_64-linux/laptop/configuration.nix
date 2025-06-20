{ pkgs, namespace, lib, ... }:

with lib.${namespace};
{
  imports = [
    ./hardware-configuration.nix
    ./hardware-extra.nix
  ];

  ${namespace} = {
    apps = enabled;
    docker = enabled;
    gpu.nvidiaMX350 = {
      enable = true;
      prime_config = {
        sync = enabled;
        nvidiaBusId = "PCI:1:0:0";
        intelBusId = "PCI:0:2:0";
      };
    };
    metrics.prometheus = enabled;
    ssh = enabled;
    laptop = enabled;

    rdp = disabled;
    gaming = enabled;
    gpu.nvidia1080ti = disabled;
  };

  networking = {
    hostName = "laptop";
    networkmanager.enable = true;
    # wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.roey = {
    isNormalUser = true;
    description = "roey";
    extraGroups = [
      "networkmanager"
      "wheel" # Enable ‘sudo’ for the user.
      "docker"
      "libvirtd" # for using libvirtd VM technology
    ];
    shell = pkgs.zsh;
  };

  # enable zsh for users
  programs.zsh.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
