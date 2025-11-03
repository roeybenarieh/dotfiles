{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.ssh;
in
{
  options.${namespace}.virtualization = with types; {
    enable = mkBoolOpt false "Whether or not to enable virtualization technoligy.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # libverto related
      libverto

      # spice
      spice
      spice-protocol

      # windows specific staffs
      virtio-win
      win-spice
    ];

    # UI for managing libvirt VMs
    programs.virt-manager = enabled;

    # https://stackoverflow.com/questions/60907105/what-is-the-difference-between-qemu-kvm-libvirt-and-how-to-use-with-vagrant
    virtualisation = {
      libvirtd = {
        enable = true;
        qemu = {
          swtpm.enable = true;
        };
      };
      spiceUSBRedirection.enable = true;
    };
    # spice docs: https://www.spice-space.org/spice-for-newbies.html
    # when installing spice guest tools, allow for better integration with VM.
    services.spice-vdagentd.enable = true;
  };
}
