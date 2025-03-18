{ pkgs, namespace, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  ${namespace} = {
    apps.enable = true;
    docker.enable = true;
    # gaming.enable = true;
    # gpu.nvidia1080ti.enable = true;
    gpu.nvidiaMX350 = {
      enable = true;
      prime_config = {
        sync.enable = true;
        nvidiaBusId = "PCI:1:0:0";
        intelBusId = "PCI:0:2:0";
      };
    };
    metrics.prometheus.enable = true;
    # rdp.enable = true;
    ssh.enable = true;
    laptop.enable = true;
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
