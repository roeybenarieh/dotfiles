{ pkgs, namespace, lib, ... }:

with lib;
with lib.${namespace};
let
  otel_traces_grpc_port = 11907;
in
{
  imports = [
    ./hardware-configuration.nix
    ./hardware-extra.nix
  ];

  ${namespace} = {
    networking.hostName = "laptop";
    apps = enabled;
    desktop = {
      enable = mkForce false;
      gnome = enabled;
    };

    docker = enabled;
    containerization.k3s = disabled;
    gpu.nvidiaMX350 = {
      enable = false;
      prime_config = {
        sync = enabled;
        nvidiaBusId = "PCI:1:0:0";
        intelBusId = "PCI:0:2:0";
      };
    };
    observability = {
      grafana = enabled;
      metrics = {
        scraping = {
          node = enabled;
          systemd = enabled;
        };
        prometheus = {
          enable = true;
          inherit otel_traces_grpc_port;
        };
        thanos = {
          enable = true;
          inherit otel_traces_grpc_port;
        };
      };
      traces.tempo = {
        enable = true;
        inherit otel_traces_grpc_port;
      };
      logs.loki = enabled;
      opentelemetry = enabled;
    };
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
    gaming = disabled;
    gpu.nvidia1080ti = disabled;
  };

  # systemd.services."preload-firefox" = {
  #   description = "Preload Firefox into RAM";
  #   wantedBy = [ "multi-user.target" ]; # preload at boot
  #   serviceConfig = {
  #     Type = "oneshot";
  #     ExecStart = ''
  #       ${pkgs.vmtouch}/bin/vmtouch -t -l ${pkgs.firefox}
  #     '';
  #   };
  # };


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
