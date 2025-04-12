{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.gpu.nvidiaMX350;
in
{
  options.${namespace}.gpu.nvidiaMX350 = with types; {
    enable = mkBoolOpt false "Whether or not to enable nvidia MX350 GPU.";
    prime_config = mkOpt lib.types.attrs { } "Prime configuration for nvidia MX350 GPU.";
  };

  config = mkIf cfg.enable {
    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.graphics.enable = true;
    nixpkgs.config.nvidia.acceptLicence.enable = true;
    hardware.nvidia = {
      open = false;
      modesetting.enable = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.latest;

      # handling two graphics cards
      # more info in: https://nixos.wiki/wiki/Nvidia
      prime = cfg.prime_config;
    };
    environment.systemPackages = with pkgs; [ furmark ];
  };
}
