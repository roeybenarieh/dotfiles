{ namespace, lib, config, pkgs, inputs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.edge-device;
  gmail-icon = pkgs.fetchurl {
    url = "https://upload.wikimedia.org/wikipedia/commons/7/7e/Gmail_icon_%282020%29.svg";
    sha256 = "sha256-3hKd/5OcNBvmu1YXZXGclTYvAh25NuiKdFV2LmiH+wU=";
  };
in
{
  options.${namespace}.edge-device = with types; {
    enable = mkBoolOpt false "Whether or not to enable edge-device (desktop/laptop) apps.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      # file system
      baobab # disk usage GUI
      nautilus # file explorer

      # clipboard
      xclip # sharing system clipboard with terminal clipboard
    ];

    # Rebuild the hicolor icon cache so Nautilus can find icons from home-manager packages.
    home.activation.updateIconCache = inputs.home-manager.lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      ${pkgs.gtk3}/bin/gtk-update-icon-cache --force --ignore-theme-index \
        "$HOME/.nix-profile/share/icons/hicolor" || true
    '';

    # set nauilus as default folder explorer
    # Make Gmail the default mailto handler
    xdg.mimeApps.defaultApplications = {
      "inode/directory" = "nautilus";
      "x-scheme-handler/mailto" = [ "gmail.desktop" ];
    };

    # Define Gmail as a desktop application
    xdg.desktopEntries.gmail = {
      name = "Gmail";
      comment = "Google mail application";
      exec = ''xdg-open "https://mail.google.com/mail"'';
      terminal = false;
      type = "Application";
      icon = gmail-icon;
      mimeType = [ "x-scheme-handler/mailto" ];
    };
  };
}
