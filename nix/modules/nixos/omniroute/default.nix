{ namespace, lib, config, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.omniroute;
in
{
  options.${namespace}.omniroute = with types; {
    enable = mkBoolOpt false "Enable OmniRoute AI gateway (local proxy for 290+ AI providers).";
    port = mkIntOpt 20128 "Port OmniRoute listens on.";
    image = mkstrOpt "diegosouzapw/omniroute:latest" "Docker image to use.";
    dataDir = mkstrOpt "/var/lib/omniroute" "Persistent data directory for OmniRoute's SQLite database.";
    jwtSecret = mkstrOpt "9g1zdbpMmteZGdH7LSySoNQNMyCemLHy6j8HHkFLEfJDzVG4" "JWT signing key for dashboard sessions.";
    apiKeySecret = mkstrOpt "d54c367b832d957b59ef766866363484db7d9e7f21429dd086ede6ce725990a5" "Encryption key for API keys stored in the database.";
    initialPassword = mkstrOpt "omniroute123" "Initial dashboard admin password.";
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers = {
      backend = "docker";
      containers.omniroute = {
        image = cfg.image;
        ports = [ "127.0.0.1:${toString cfg.port}:20128" ];
        volumes = [ "${cfg.dataDir}:/app/data" ];
        environment = {
          DATA_DIR = "/app/data";
          REQUIRE_API_KEY = "false";
          JWT_SECRET = cfg.jwtSecret;
          API_KEY_SECRET = cfg.apiKeySecret;
          INITIAL_PASSWORD = cfg.initialPassword;
        };
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0777 root root -"
    ];
  };
}
