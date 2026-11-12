{ pkgs, namespace, lib, ... }:

with lib.${namespace};
{
  imports = [
    ./hardware-extra.nix
  ];

  ${namespace} = {
    networking.hostName = "server";
    containerization.k3s = enabled;
    observability = {
      grafana = enabled;
      metrics = {
        scraping = {
          node = enabled;
        };
        prometheus = {
          enable = true;
        };
      };
    };
    ssh = enabled;
    tailscale = {
      enable = true;
      operator = "remote";
    };
    # tmux
  };


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
