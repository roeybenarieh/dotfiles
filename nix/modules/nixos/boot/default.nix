{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.boot;
in
{
  options.${namespace}.boot = with types; {
    enable = mkBoolOpt true "Whether or not to enable boot configuration.";
  };

  config = mkIf cfg.enable {
    boot.loader = {
      timeout = 2;
      systemd-boot = {
        enable = true;
        configurationLimit = 50; # limit the amount of boot options
        # disable editing kernel command-line before boot, 
        # prevents access to root in case of physical access to the machine.
        editor = false;
      };
      efi.canTouchEfiVariables = true;

      grub = {
        enable = false;
        configurationLimit = 50; # limit the amount of boot options
        efiSupport = true;

        # disable editing kernel command-line before boot, 
        # prevents access to root in case of physical access to the machine.
        # Disable GRUB’s built-in editor
        extraConfig = ''
          set allow_config_editor=false
          set superusers=""
        '';
        # terminal_output gfxterm

        device = "nodev";
        # devices = [ "nodev" ]; # change this to your actual disk
        useOSProber = true;

        # Optional: if you dual-boot
        # osProber = true;

        # Theme setup
        # theme = pkgs.fetchurl {
        #   url = "https://github.com/vinceliuice/grub2-themes/releases/download/2024-05-01/Vimix.tar.xz";
        #   sha256 = "sha256-vhyER8mU7PHDZPpR84tu5WqfEAVZfFgTV4OlUjE5Iqw=";
        # };

        # gfxmodeBios = "1920x1080";
        # gfxmodeEfi = "1920x1080";
      };
      grub2-theme = {
        enable = false;
        theme = "whitesur";
        icon = "whitesur";
        footer = true;
        customResolution = "1920x1080"; # Optional: Set a custom resolution
      };
    };
    boot.plymouth = {
      enable = false;
      theme = "breeze"; # optional: splash screen before login
    };
  };
}
