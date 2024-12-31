{ config, lib, pkgs, modulesPath, ... }:

{
  hardware.graphics = {
    enable = true;
    # driSupport = true;
    # enable32Bit = true;
  };

  # services.xserver.videoDrivers = [ "amdgpu" ];

  programs.steam.enable = true;
  programs.steam.gamescopeSession.enable = true;
  programs.gamemode.enable = true;

  environment.systemPackages = with pkgs; [
    protonup
    protonup-qt # protonup UI
  ];
  environment.sessionVariables = {
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "~/.steam/root/compatibilitytools.d";
  };
}
