{ pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../common/ssh.nix
    ../common/rdp.nix
    ../common/system_utils.nix
    ../common/metrics
    ../common/foldathome.nix
    ../common/ssd.nix
    ../common/resource-optimization.nix
    ../common/audio.nix
    ../common/i18n.nix
    ../common/xserver.nix
    ./hardware-extra.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 150; # limit the amount of boot options
    # disable editing kernel command-line before boot, 
    # prevents access to root in case of physical access to the machine.
    editor = false;
  };
  boot.loader.efi.canTouchEfiVariables = true;

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

  # virtualisation
  virtualisation.docker.enable = true;

  # nix related
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

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

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [ vim curl git ];

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
