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
      # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
      # Enable this if you have graphical corruption issues or application crashes after waking
      # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead 
      # of just the bare essentials.
      powerManagement.enable = true;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
    };
    environment.systemPackages = with pkgs; [ furmark ];
  };
}
 
