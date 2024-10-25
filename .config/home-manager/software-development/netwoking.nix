{ config, pkgs, ... }:

{
  home.packages = with pkgs; [ curl wget postman ];
  # sshx for sharing ssh sessions
  programs.ssh.enable = true;
}
