{ inputs, pkgs, lib, ... }:

with lib;
{
  # nix flake show github:NixOS/nixos-hardware/master | grep common
  imports = with inputs.nixos-hardware.nixosModules; [
    common-pc-laptop
    common-pc-laptop-ssd
  ];
  hardware.enableAllFirmware = true;

  # Tell ACPI firmware it's running on Linux so it doesn't use Windows-specific
  # code paths that cause IRQ/9 (ACPI SCI) interrupt storms on Lenovo hardware.
  boot.kernelParams = [ "acpi_osi=Linux" ];

  # Lenovo's ECDT assigns the EC to GPE 0x6e, but its events arrive on 0x43.
  # Correct the table before the EC driver starts; masking 0x43 loses EC events
  # and does not prevent the immediate s2idle wakeup.
  # https://bugzilla.kernel.org/show_bug.cgi?id=207749#c80
  boot.initrd.prepend = [
    "${pkgs.runCommand "lenovo-ecdt.cpio" { nativeBuildInputs = [ pkgs.acpica-tools pkgs.cpio ]; } ''
      cp ${./ecdt.dsl} ecdt.dsl
      iasl -p ECDT ecdt.dsl
      mkdir -p kernel/firmware/acpi
      cp ECDT.aml kernel/firmware/acpi/ECDT.aml
      printf '%s\n' kernel/firmware/acpi/ECDT.aml | cpio --quiet -o -H newc --reproducible > "$out"
    ''}"
  ];

  # Remap keys: this laptop's firmware sends F<num> instead of the appropriate special keymaps
  # (i.e. XF86MonBrightnessUp/Down keysyms for brightness control), so fix it at the X11 level.
  services.xserver.displayManager.sessionCommands = ''
    xmodmap=${getExe pkgs.xmodmap}
    $xmodmap -e "keycode 67 = XF86AudioMute"        # F1
    $xmodmap -e "keycode 68 = XF86AudioLowerVolume" # F2
    $xmodmap -e "keycode 69 = XF86AudioRaiseVolume" # F3
    $xmodmap -e "keycode 71 = XF86MonBrightnessDown"  # F5
    $xmodmap -e "keycode 72 = XF86MonBrightnessUp" # F6
  '';
}
