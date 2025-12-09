{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.storage.minio;

  # Script that creates all buckets
  createBucketsScript = pkgs.writeShellScriptBin "create-minio-buckets" ''
    # Wait for MinIO to be ready
    until ${getExe pkgs.curl} -s -o /dev/null -w "%{http_code}" ${http_local_endpoint_on_port cfg.port}/minio/health/live | ${getExe pkgs.gnugrep} -q "200"; do
      sleep 1
    done

    # Configure alias
    ${getExe pkgs.minio-client} alias set local ${http_local_endpoint_on_port cfg.port} ${cfg.accessKey} ${cfg.secretKey} --api s3v4

    # Create each bucket
    ${lib.concatMapStrings (bucket: ''
      echo "Creating bucket: ${bucket}"
      ${getExe pkgs.minio-client} mb --ignore-existing local/${bucket}
    '') cfg.bucketNames}
  '';
in
{
  options.${namespace}.storage.minio = with types; {
    enable = mkBoolOpt false "Whether or not to enable minio S3 storage.";
    port = mkIntOpt 11906 "minio api port";
    bucketNames = mkListOpt [ ] "minio buckets to create";
    region = mkstrOpt "us-east-1" "minio region";
    accessKey = mkstrOpt "minio_accesskey" "minio username";
    secretKey = mkstrOpt "minio_secretkey" "minio password";
  };

  config = mkIf cfg.enable {

    services.minio = {
      enable = true;
      inherit (cfg) region;
      listenAddress = ":${toString cfg.port}";
      consoleAddress = ":9001"; # web UI port
      rootCredentialsFile = pkgs.writeText "minio-credentials-partial" ''
        MINIO_ROOT_USER=${cfg.accessKey}
        MINIO_ROOT_PASSWORD=${cfg.secretKey}
      '';
    };

    # configure prometheus monitoring
    systemd.services.minio.serviceConfig.Environment = "MINIO_PROMETHEUS_AUTH_TYPE=public";
    services.prometheus = {
      scrapeConfigs = [
        {
          job_name = "minio";
          metrics_path = "/minio/v2/metrics/cluster";
          static_configs = [{
            targets = [ (schemaless_local_endpoint_on_port 11906) ];
          }];
        }
      ];
    };

    systemd.services.create-minio-buckets = {
      serviceConfig = {
        Type = "oneshot"; # Run once and exit
        ExecStart = "${createBucketsScript}/bin/create-minio-buckets";
        Restart = "on-failure";
        User = "root";
        StandardOutput = "journal";
        StandardError = "journal";
      };

      description = "Automatically create minio buckets";
      after = [ "minio.service" ];
      requires = [ "minio.service" ];
      wantedBy = [ "multi-user.target" ];
    };
  };
} 
