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
    # TODO: for the love of god, when installing stremio make sure to disable caching!!!
    # from my experience it make stremio playing videos WAY MORE smoothly
    home.packages = with pkgs;[
      stremio-linux-shell # streaming app
      # TODO: find a better place for krita
      krita # GUI paint app
      spotify
    ];

    xdg.configFile."spotify-adblock/config.toml".text = ''
      allowlist = [
          'localhost',
          'audio-sp-.*\.pscdn\.co',
          'audio-fa\.scdn\.co',
          'audio4-fa\.scdn\.co',
          'charts-images\.scdn\.co',
          'daily-mix\.scdn\.co',
          'dailymix-images\.scdn\.co',
          'heads-fa\.scdn\.co',
          'i\.scdn\.co',
          'lineup-images\.scdn\.co',
          'merch-img\.scdn\.co',
          'misc\.scdn\.co',
          'mosaic\.scdn\.co',
          'newjams-images\.scdn\.co',
          'o\.scdn\.co',
          'pl\.scdn\.co',
          'profile-images\.scdn\.co',
          'seeded-session-images\.scdn\.co',
          't\.scdn\.co',
          'thisis-images\.scdn\.co',
          'video-fa\.scdn\.co',
          '.*\.acast\.com',
          'content\.production\.cdn\.art19\.com',
          'rss\.art19\.com',
          '.*\.buzzsprout\.com',
          'chtbl\.com',
          'platform-lookaside\.fbsbx\.com',
          'genius\.com',
          '.*\.googlevideo\.com',
          '.*\.gvt1\.com',
          'content\.libsyn\.com',
          'hwcdn\.libsyn\.com',
          'traffic\.libsyn\.com',
          'api.*-desktop\.musixmatch\.com',
          '.*\.podbean\.com',
          'cdn\.podigee\.com',
          'dts\.podtrac\.com',
          'www\.podtrac\.com',
          'www\.reddit\.com',
          'audio\.simplecast\.com',
          'media\.simplecast\.com',
          'ap\.spotify\.com',
          '.*\.ap\.spotify\.com',
          'ap-.*\.spotify\.com',
          'api\.spotify\.com',
          'api-partner\.spotify\.com',
          'xpui\.app\.spotify\.com',
          'apresolve\.spotify\.com',
          'clienttoken\.spotify\.com',
          '.*dealer.*\.spotify\.com',
          'image-upload.*\.spotify\.com',
          'login.*\.spotify\.com',
          '.*-spclient\.spotify\.com',
          'spclient\.wg\.spotify\.com',
          'audio-fa\.spotifycdn\.com',
          'mixed-media-images\.spotifycdn\.com',
          'seed-mix-image\.spotifycdn\.com',
          'api\.spreaker\.com',
          'download\.ted\.com',
          'www\.youtube\.com',
          'i\.ytimg\.com',
          'chrt\.fm',
          'dcs.*\.megaphone\.fm',
          'traffic\.megaphone\.fm',
          'pdst\.fm',
          'audio-ak-spotify-com\.akamaized\.net',
          'audio-akp-spotify-com\.akamaized\.net',
          'audio4-ak-spotify-com\.akamaized\.net',
          'heads4-ak-spotify-com\.akamaized\.net',
          '.*\.cloudfront\.net',
          'audio4-ak\.spotify\.com\.edgesuite\.net',
          'scontent.*\.fbcdn\.net',
          'audio-sp-.*\.spotifycdn\.net',
          'dovetail\.prxu\.org',
          'dovetail-cdn\.prxu\.org',
      ]

      denylist = [
          'https://spclient\.wg\.spotify\.com/ads/.*',
          'https://spclient\.wg\.spotify\.com/ad-logic/.*',
          'https://spclient\.wg\.spotify\.com/gabo-receiver-service/.*',
      ]
    '';

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
