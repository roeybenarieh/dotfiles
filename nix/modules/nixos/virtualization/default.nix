{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.ssh;
in
{
  options.${namespace}.virtualization = with types; {
    enable = mkBoolOpt false "Whether or not to enable virtualization technoligies.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      gnome-boxes
    ];

    virtualisation = {
      libvirtd = {
        enable = true;
        qemu = {
          swtpm.enable = true;
          ovmf.enable = true;
          ovmf.packages = [ pkgs.OVMFFull.fd ];
        };
      };
      spiceUSBRedirection.enable = true;
    };
    # the program allows to talk with VMs
    # in order for that to work this program must be installed on the host and guest machine!
    services.spice-vdagentd.enable = true;
  };
}
