{ namespace, lib, config, pkgs, inputs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.entertainment;
  spotify-adblock = pkgs.rustPlatform.buildRustPackage {
    pname = "spotify-adblock";
    version = "unstable";
    src = inputs.spotify-adblock;
    cargoLock.lockFile = "${inputs.spotify-adblock}/Cargo.lock";
    buildInputs = [ pkgs.curl pkgs.openssl ];
    nativeBuildInputs = [ pkgs.pkg-config ];
    installPhase = ''
      install -Dm755 target/${pkgs.stdenv.hostPlatform.rust.rustcTarget}/release/libspotifyadblock.so $out/lib/spotify-adblock.so
    '';
  };
in
{
  options.${namespace}.entertainment = with types; {
    enable = mkBoolOpt false "Whether or not to enable entertainment apps.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      stremio-linux-shell
      krita
      spotify
    ];

    # Disable Stremio streaming cache — improves playback smoothness significantly.
    # Uses activation so it doesn't overwrite user changes on rebuild.
    home.activation.stremioDisableCache = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      cfg_dir="$HOME/.local/share/com.stremio.stremio"
      cfg_file="$cfg_dir/app-settings.json"
      mkdir -p "$cfg_dir"
      if [ ! -f "$cfg_file" ]; then
        echo '{"cacheSize":0,"cacheEnabled":false}' > "$cfg_file"
      fi
    '';

    # Track upstream's own config.toml
    xdg.configFile."spotify-adblock/config.toml".source = "${inputs.spotify-adblock}/config.toml";

    xdg.desktopEntries.spotify = {
      name = "Spotify";
      exec = "${pkgs.coreutils}/bin/env LD_PRELOAD=${spotify-adblock}/lib/spotify-adblock.so spotify %U";
      terminal = false;
      icon = "spotify-client";
      type = "Application";
      categories = [ "Audio" "Music" "Player" ];
    };
  };
}
