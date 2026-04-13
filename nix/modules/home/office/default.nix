# NOTES: 
# WPS doesn't have good support with Hebrew.
# Maybe possible to diclerativly install windows via 
{ namespace, lib, config, pkgs, inputs, ... }:
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
      libreoffice-fresh
      powerpoint-online
      word-online

      # Hebrew fonts
      culmus
    ];
    programs.obsidian = enabled;

    # Configure LibreOffice with Hebrew CTL for automatic RTL direction detection.
    # LibreOffice automatically sets paragraph direction to RTL when Hebrew is typed.
    # only write this if the file doesn't exist yet, to avoid overwriting user changes.
    home.activation.libreofficeHebrewCTL = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            lo_config_dir="$HOME/.config/libreoffice/4/user"
            lo_config="$lo_config_dir/registrymodifications.xcu"
            mkdir -p "$lo_config_dir"
            if [ ! -f "$lo_config" ]; then
              cat > "$lo_config" << 'XMLEOF'
      <?xml version="1.0" encoding="UTF-8"?>
      <oor:items xmlns:oor="http://openoffice.org/2001/registry" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <item oor:path="/org.openoffice.Office.Writer/LanguageConfig/LanguageSettings/Languages">
          <prop oor:name="CTLLocale" oor:op="fuse">
            <value>he-IL</value>
          </prop>
        </item>
      </oor:items>
      XMLEOF
            elif ! grep -q "CTLLocale" "$lo_config"; then
              ${pkgs.gnused}/bin/sed -i 's|</oor:items>|  <item oor:path="/org.openoffice.Office.Writer/LanguageConfig/LanguageSettings/Languages">\n    <prop oor:name="CTLLocale" oor:op="fuse"><value>he-IL</value></prop>\n  </item>\n</oor:items>|' "$lo_config"
            fi
    '';

    # set default apps
    xdg.mimeApps.defaultApplications = {
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = [ "writer.desktop" ];
      "application/msword" = [ "writer.desktop" ];
      "application/vnd.oasis.opendocument.text" = [ "writer.desktop" ];

      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = [ "calc.desktop" ];
      "application/vnd.ms-excel" = [ "calc.desktop" ];
      "application/vnd.oasis.opendocument.spreadsheet" = [ "calc.desktop" ];

      "application/vnd.openxmlformats-officedocument.presentationml.presentation" = [ "impress.desktop" ];
      "application/vnd.ms-powerpoint" = [ "impress.desktop" ];
      "application/vnd.oasis.opendocument.presentation" = [ "impress.desktop" ];
    };
  };
}
