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
    image = mkstrOpt "diegosouzapw/omniroute:v3.8.49" "Docker image to use.";
    dataDir = mkstrOpt "/var/lib/omniroute" "Persistent data directory for OmniRoute's SQLite database.";

    # Secrets are loaded from an env file, NOT baked into the nix store.
    # Create /etc/omniroute/env with:
    #   JWT_SECRET=$(openssl rand -base64 48)
    #   API_KEY_SECRET=$(openssl rand -hex 32)
    #   INITIAL_PASSWORD=<choose-a-strong-password>
    envFile = mkstrOpt "/etc/omniroute/env" "Path to the secrets env file (not managed by nix).";
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers = {
      backend = "docker";
      containers.omniroute = {
        image = cfg.image;
        ports = [ "127.0.0.1:${toString cfg.port}:20128" ];
        volumes = [ "${cfg.dataDir}:/app/data" ];
        environmentFiles = [ cfg.envFile ];
        environment = {
          DATA_DIR = "/app/data";
          REQUIRE_API_KEY = "false";
        };
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 root root -"
    ];
  };
}
