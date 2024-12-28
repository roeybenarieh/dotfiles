{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    curl
    wget
    postman
    remmina # rdp(and other protocols) client
  ];
  # sshx for sharing ssh sessions
  programs.ssh.enable = true;
}
