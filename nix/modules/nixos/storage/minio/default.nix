{ namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.storage.minio;
in
{
  options.${namespace}.storage.minio = with types; {
    enable = mkBoolOpt false "Whether or not to enable minio S3 storage.";
    port = mkIntOpt 11906 "minio api port";
    accessKey = mkstrOpt "minio_accesskey" "minio username";
    secretKey = mkstrOpt "minio_secretkey" "minio password";
  };

  config = mkIf cfg.enable {

    services.minio = {
      enable = true;
      listenAddress = ":${toString cfg.port}";
      consoleAddress = ":9001"; # web UI port
      accessKey = cfg.accessKey;
      secretKey = cfg.secretKey;
    };
  };
} 
