{ config, pkgs, lib, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../common/ssh.nix
    ../common/rdp.nix
    ../common/system_utils.nix
    ../common/metrics.nix
    ./hardware-extra.nix
    # ../common/tmp.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 150; # limit the amount of boot options
  };
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostName = "home-computer"; # Define your hostname.
    networkmanager.enable = true; # Enable networking
    # TODO: make sure this is working
    interfaces = {
      enp3s0 = {
        wakeOnLan = {
          enable = true;
        };
      };
    };
  };

  # virtualisation
  virtualisation.docker.enable = true;

  # nix related
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Set your time zone.
  time.timeZone = "Asia/Tel_Aviv";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_IL";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_IL";
    LC_IDENTIFICATION = "en_IL";
    LC_MEASUREMENT = "en_IL";
    LC_MONETARY = "en_IL";
    LC_NAME = "en_IL";
    LC_NUMERIC = "en_IL";
    LC_PAPER = "en_IL";
    LC_TELEPHONE = "en_IL";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the Budgie Desktop environment.
  services.xserver = {
    displayManager.lightdm.enable = true;
    desktopManager.budgie.enable = true;
    windowManager.qtile = {
      enable = true;
      extraPackages = python3Packages: with python3Packages; [
        qtile-extras
        pydexcom
        colour
      ];
    };
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "il";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

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
    packages = with pkgs;
      [
        #  thunderbird
        fzf
      ];
  };

  # Enable automatic login for the user.
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "roey";

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
  system.stateVersion = "24.05"; # Did you read the comment?

}
