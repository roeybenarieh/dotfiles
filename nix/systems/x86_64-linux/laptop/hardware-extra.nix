{ inputs, ... }:

{
  # nix flake show github:NixOS/nixos-hardware/master | grep common
  imports = with inputs.nixos-hardware.nixosModules; [
    common-pc-laptop
    common-pc-laptop-ssd
  ];
  hardware.enableAllFirmware = true;

}
