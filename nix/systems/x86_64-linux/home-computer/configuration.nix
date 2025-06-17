{ pkgs, namespace, ... }:

{
  imports = [
    ./hardware-extra.nix
  ];

  ${namespace} = {
    apps.enable = true;
    docker.enable = true;
    gaming.enable = true;
    gpu.nvidia1080ti.enable = true;
    metrics.prometheus.enable = true;
    rdp.enable = true;
    ssh.enable = true;
    razer.enable = true;
    virtualization.enable = true;
  };

  networking = {
    hostName = "home-computer"; # Define your hostname.
    networkmanager.enable = true; # Enable networking
    # TODO: make sure this is working
    # interfaces = {
    #   enp3s0 = {
    #     wakeOnLan = {
    #       enable = true;
    #     };
    #   };
    # };
  };
  # nix related
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # enable zsh for users
  programs.zsh.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.roey = {
    isNormalUser = true;
    description = "roey";
    extraGroups = [
      "networkmanager"
      "wheel" # Enable ‘sudo’ for the user.
      "docker"
    ];
    shell = pkgs.zsh;
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
