{ namespace, lib, config, pkgs, inputs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.entertainment;
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  options.${namespace}.entertainment = with types; {
    enable = mkBoolOpt false "Whether or not to enable entertainment apps.";
  };

  config = mkIf cfg.enable {
    # TODO: for the love of god, when installing stremio make sure to disable caching!!!
    # from my experience it make stremio playing videos WAY MORE smoothly
    home.packages = with pkgs;[
      stremio-linux-shell # streaming app
      # TODO: find a better place for krita
      krita # GUI paint app
    ];

    xdg.desktopEntries.spotify = {
      name = "Spotify";
      exec = "${getExe pkgs.cpulimit} --include-children --limit 200 -- spotify %U";
      terminal = false;
      icon = "spotify-client";
      type = "Application";
      categories = [ "Audio" "Music" "Player" ];
    };
    # Spicetify (Spotify)
    programs.spicetify = {
      enable = true;
      enabledExtensions = with spicePkgs.extensions; [
        adblock
        catJamSynced # cat follows mouse
        keyboardShortcut # vim like keyboard shortcuts
        songStats # show more start on each song
        autoSkipVideo
      ];
    };
  };
}
