{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.office;

  # general staff
  onedrive-url = "https://onedrive.live.com";
  exec = "${config.home.shellAliases.open} ${onedrive-url}";
  categories = [ "Office" "X-Microsoft" ];
  word-application-name = "Microsoft Word 2013";
  poweroint-application-name = "Microsoft Powerpoint 2013";
  word-online-name = "Microsoft Word Online";
  powerpoint-online-name = "Microsoft Powerpoint Online";

  # functions
  # NOTE: this wrapper exists because playonlinux is using wine, hence in order for the wine app to get the file it needs to be pre-processed.
  # FIX: file path with none-latin characters crashes playonlinux programs
  # TODO: better support for hebrew characters in office programs
  play_on_linux_exec_wrap = application:
    "${pkgs.writeShellScript "wrapper" ''
      #!/bin/sh
      playonlinux --run "${application}" "$1"
    ''} %f";

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
    xdg.desktopEntries = {
      ${word-application-name} = {
        name = word-application-name;
        exec = play_on_linux_exec_wrap word-application-name;
        icon = word-icon;
        mimeType = [ "application/vnd.openxmlformats-officedocument.wordprocessingml.document" ];
        # startupNotify = true;
        terminal = false;
        inherit categories;
      };
      ${poweroint-application-name} = {
        name = poweroint-application-name;
        exec = play_on_linux_exec_wrap poweroint-application-name;
        icon = powerpoint-icon;
        mimeType = [ "application/vnd.openxmlformats-officedocument.presentationml.presentation" ];
        # startupNotify = true;
        terminal = false;
        inherit categories;
      };
    };
    home.packages = with pkgs; [
      # onlyoffice-bin
      powerpoint-online
      word-online

      # TODO: make the installation declaritevly + set mime types
      # before watching windows below, mount .iso file, there you would find the setup.exe file.
      # NOTE: the iso is commited to this repository because after a few mounths the .iso installation URLs are taken down
      # microsoft office installation instructions: https://www.youtube.com/watch?v=LH-6tp-KBuQ&t=66s
      playonlinux
      samba
    ];
    programs.obsidian = enabled;
  };
}
