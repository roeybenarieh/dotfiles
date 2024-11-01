{ config, pkgs, ... }:

{
  home.packages = with pkgs; [ curl wget postman ];
  # sshx for sharing ssh sessions
  programs.ssh.enable = true;
  # rdp(and other protocols) client
  services.remmina = {
    enable = true;
    addRdpMimeTypeAssoc = true;
  };
}
