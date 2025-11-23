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
    containerization.k3s = enabled;
    gpu.nvidiaMX350 = {
      enable = false;
      prime_config = {
        sync = enabled;
        nvidiaBusId = "PCI:1:0:0";
        intelBusId = "PCI:0:2:0";
      };
    };
    metrics.prometheus = enabled;
    ssh = enabled;
    laptop = enabled;
    graphics.displays = {
      enable = true;
      builtInDisplay = {
        fingerprint = "00ffffffffffff000daef515000000000c1d0104a52213780228659759548e271e505400000001010101010101010101010101010101363680a0703820403020a60058c110000018000000fe004e3135364847412d4541330a20000000fe00434d4e0a202020202020202020000000fe004e3135364847412d4541330a200006";
        config = {
          mode = "1920x1080";
          rotate = "normal";
        };
      };
    };

    rdp = disabled;
    gaming = enabled;
    gpu.nvidia1080ti = disabled;
  };

  # systemd.services."preload-firefox" = {
  #   description = "Preload Firefox into RAM";
  networking = {
    hostName = "laptop";
    networkmanager.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
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
