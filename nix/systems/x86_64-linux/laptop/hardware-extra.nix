{ inputs, ... }:

{
  # better DPI for my laptop screen, help with scaling UI elements
  services.xserver.dpi = 125;

  # nix flake show github:NixOS/nixos-hardware/master | grep common
  imports = with inputs.nixos-hardware.nixosModules; [
    common-pc-laptop
    common-pc-laptop-ssd
  ];
  hardware.enableAllFirmware = true;

}
