{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.office;

  powerpoint-icon = pkgs.fetchurl {
    url = "https://upload.wikimedia.org/wikipedia/commons/0/0d/Microsoft_Office_PowerPoint_%282019%E2%80%93present%29.svg";
    sha256 = "sha256-rc3WUkFDIqEUpp+Nna7HkXQyMjMvDH7u749pCOXlcGc=";
  };
  word-icon = pkgs.fetchurl {
    url = "https://upload.wikimedia.org/wikipedia/commons/f/fd/Microsoft_Office_Word_%282019%E2%80%93present%29.svg";
    sha256 = "sha256-oPvT1JtNwPLFrFGAeTiZhdvVCyhPpu2VElwWYLl3u+s=";
  };
  onedrive-url = "https://onedrive.live.com";
  powerpoint = pkgs.makeDesktopItem {
    name = "Microsoft powerpoint";
    exec = "${config.home.shellAliases.open} ${onedrive-url}";
    desktopName = "Powerpoint";
    genericName = "Slides/presentation Editor - Google Sheets";
    categories = [ "Office" "X-Microsoft" ];
    icon = powerpoint-icon;
  };
  word = pkgs.makeDesktopItem {
    name = "Microsoft word";
    exec = "${config.home.shellAliases.open} ${onedrive-url}";
    desktopName = "Word";
    genericName = "Document Editor - Google Docs";
    categories = [ "Office" "X-Microsoft" ];
    icon = word-icon;
  };
in
{
  options.${namespace}.office = with types; {
    enable = mkBoolOpt false "Whether or not to enable support office documents and editors.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      onlyoffice-bin
      powerpoint
      word
    ];
  };
}
