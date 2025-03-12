{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.gpu.nvidia1080ti;
in
{
  options.${namespace}.gpu.nvidia1080ti = with types; {
    enable = mkBoolOpt false "Whether or not to enable nvidia 1080ti GPU.";
  };

  config = mkIf cfg.enable {
    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.graphics.enable = true;
    nixpkgs.config.nvidia.acceptLicence.enable = true;
    hardware.nvidia = {
      open = false;
      modesetting.enable = true;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
    };
    environment.systemPackages = with pkgs; [ furmark ];
  };
}
 
