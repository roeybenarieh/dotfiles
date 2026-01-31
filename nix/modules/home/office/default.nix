{ namespace, lib, config, pkgs, inputs, system, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.office;

  # general staff
  onedrive-url = "https://onedrive.live.com";
  exec = "${config.home.shellAliases.open} ${onedrive-url}";
  categories = [ "Office" "X-Microsoft" ];
  word-online-name = "Microsoft Word Online";
  powerpoint-online-name = "Microsoft Powerpoint Online";
  # NOTE: for some reason the wps package provided is not working...
  # wpsoffice = inputs.wpsoffice.packages.${system}.default;
  wpsoffice-fonts = inputs.wpsoffice.packages.${system}.fonts;

  # assets
  powerpoint-icon = pkgs.fetchurl {
    url = "https://upload.wikimedia.org/wikipedia/commons/0/0d/Microsoft_Office_PowerPoint_%282019%E2%80%93present%29.svg";
    sha256 = "sha256-rc3WUkFDIqEUpp+Nna7HkXQyMjMvDH7u749pCOXlcGc=";
  };
  word-icon = pkgs.fetchurl {
    url = "https://upload.wikimedia.org/wikipedia/commons/f/fd/Microsoft_Office_Word_%282019%E2%80%93present%29.svg";
    sha256 = "sha256-oPvT1JtNwPLFrFGAeTiZhdvVCyhPpu2VElwWYLl3u+s=";
  };

  # desktop items
  powerpoint-online = pkgs.makeDesktopItem {
    name = powerpoint-online-name;
    inherit exec;
    desktopName = powerpoint-online-name;
    genericName = "Slides/presentation Editor";
    inherit categories;
    icon = powerpoint-icon;
  };
  word-online = pkgs.makeDesktopItem {
    name = word-online-name;
    inherit exec;
    desktopName = word-online-name;
    genericName = "Document Editor";
    inherit categories;
    icon = word-icon;
  };

in
{
  options.${namespace}.office = with types; {
    enable = mkBoolOpt false "Whether or not to enable support office documents and editors.";
  };

  config = mkIf cfg.enable {
    fonts.fontconfig = enabled;
    home.packages = with pkgs; [
      # onlyoffice-bin
      wpsoffice
      powerpoint-online
      word-online

      # run 'fc-cache -rf' when changing/installing fonts
      wpsoffice-fonts
    ];
    programs.obsidian = enabled;

    # set default apps
    xdg.mimeApps.defaultApplications = {
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = [ "wps-office-wps.desktop" ];
      "application/msword" = [ "wps-office-wps.desktop" ];
      "application/vnd.oasis.opendocument.text" = [ "wps-office-wps.desktop" ];

      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = [ "wps-office-et.desktop" ];
      "application/vnd.ms-excel" = [ "wps-office-et.desktop" ];
      "application/vnd.oasis.opendocument.spreadsheet" = [ "wps-office-et.desktop" ];

      "application/vnd.openxmlformats-officedocument.presentationml.presentation" = [ "wps-office-wpp.desktop" ];
      "application/vnd.ms-powerpoint" = [ "wps-office-wpp.desktop" ];
      "application/vnd.oasis.opendocument.presentation" = [ "wps-office-wpp.desktop" ];
    };
  };
}
