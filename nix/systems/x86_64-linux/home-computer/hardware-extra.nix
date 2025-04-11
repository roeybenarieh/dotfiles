{ inputs, ... }:

{
  # nix flake show github:NixOS/nixos-hardware/master | grep common
  imports = with inputs.nixos-hardware.nixosModules; [
    common-pc-ssd
    common-pc
    common-cpu-intel-cpu-only
    common-gpu-nvidia-nonprime
  ];
  hardware.enableAllFirmware = true;
}
