{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.storage.s3compatible;

  garagePkg = pkgs.garage;
  adminPort = 3903;
  keyName = "default";

  keyId = s3compatible_key_id cfg.accessKey;
  keySecret = s3compatible_key_secret cfg.secretKey;
  rpcSecret = builtins.hashString "sha256" "${cfg.secretKey}-rpc";

  # rclone remote pointing at the local Garage S3 API, used to drive rclone's
  # built-in web UI (rcd --rc-web-gui) for browsing/managing buckets
  rcloneConfig = pkgs.writeText "s3compatible-rclone.conf" ''
    [s3compatible]
    type = s3
    provider = Other
    access_key_id = ${keyId}
    secret_access_key = ${keySecret}
    endpoint = http://localhost:${toString cfg.port}
    region = ${cfg.region}
  '';

  # Script that bootstraps the single-node cluster layout, imports the access
  # key and creates/grants all requested buckets
  createBucketsScript = pkgs.writeShellScriptBin "create-s3compatible-buckets" ''
    set -euo pipefail

    # Wait for the server to be ready
    until ${getExe pkgs.curl} -s -o /dev/null -w "%{http_code}" ${http_local_endpoint_on_port adminPort}/health | ${getExe pkgs.gnugrep} -q "200"; do
      sleep 1
    done

    NODE_ID="$(${getExe garagePkg} node id -q | ${pkgs.coreutils}/bin/cut -d@ -f1)"

    # Assign this node its single-node cluster layout, if it doesn't have one yet
    if ! ${getExe garagePkg} status | ${getExe pkgs.gnugrep} -q "$NODE_ID"; then
      CAPACITY="$(${pkgs.coreutils}/bin/df --output=avail -B1 /var/lib/garage/data | ${pkgs.coreutils}/bin/tail -n1 | ${pkgs.coreutils}/bin/tr -d ' ')"
      ${getExe garagePkg} layout assign -z local -c "$CAPACITY" "$NODE_ID"
      CUR_VER="$(${getExe garagePkg} layout show | ${getExe pkgs.gnugrep} -oP 'Current cluster layout version:\s*\K[0-9]+')"
      ${getExe garagePkg} layout apply --version "$((CUR_VER + 1))"
    fi

    # Import the access key
    ${getExe garagePkg} key list | ${getExe pkgs.gnugrep} -q "${keyName}$" || ${getExe garagePkg} key import "${keyId}" "${keySecret}" -n "${keyName}" --yes

    # Create each bucket
    ${lib.concatMapStrings (bucket: ''
      echo "Creating bucket: ${bucket}"
      ${getExe garagePkg} bucket list | ${getExe pkgs.gnugrep} -q " ${bucket} " || ${getExe garagePkg} bucket create "${bucket}"
      ${getExe garagePkg} bucket allow --read --write --owner "${bucket}" --key "${keyName}"
      ${getExe garagePkg} bucket set-quotas --max-size "${cfg.bucketMaxSize}" "${bucket}"
    '') cfg.bucketNames}
  '';
in
{
  options.${namespace}.storage.s3compatible = with types; {
    enable = mkBoolOpt false "Whether or not to enable s3compatible S3 storage.";
    port = mkIntOpt 11906 "s3compatible api port";
    webUiPort = mkIntOpt 11910 "s3compatible web UI port, for browsing/managing buckets";
    bucketNames = mkListOpt [ ] "s3compatible buckets to create";
    bucketMaxSize = mkstrOpt "1GB" "Max size quota applied to each bucket (garage bucket set-quotas --max-size), e.g. \"1GB\" or \"none\" for no limit";
    region = mkstrOpt "us-east-1" "s3compatible region";
    accessKey = mkstrOpt "s3compatible_accesskey" "s3compatible username";
    secretKey = mkstrOpt "s3compatible_secretkey" "s3compatible password";
  };

  config = mkIf cfg.enable {

    services.garage = {
      enable = true;
      package = garagePkg;
      settings = {
        replication_factor = 1;
        rpc_bind_addr = "127.0.0.1:3901";
        rpc_public_addr = "127.0.0.1:3901";
        rpc_secret = rpcSecret;

        s3_api = {
          api_bind_addr = "0.0.0.0:${toString cfg.port}";
          s3_region = cfg.region;
        };

        admin.api_bind_addr = "127.0.0.1:${toString adminPort}"; # metrics + health, publicly readable (no admin/metrics token set)
      };
    };

    services.prometheus = {
      scrapeConfigs = [
        {
          job_name = "s3compatible";
          metrics_path = "/metrics";
          static_configs = [{
            targets = [ (schemaless_local_endpoint_on_port adminPort) ];
          }];
        }
      ];
    };

    systemd.services.create-s3compatible-buckets = {
      serviceConfig = {
        Type = "oneshot"; # Run once and exit
        ExecStart = "${createBucketsScript}/bin/create-s3compatible-buckets";
        Restart = "on-failure";
        User = "root";
        StandardOutput = "journal";
        StandardError = "journal";
      };

      description = "Automatically bootstrap the s3compatible cluster layout and create buckets";
      after = [ "garage.service" ];
      requires = [ "garage.service" ];
      wantedBy = [ "multi-user.target" ];
    };

    systemd.services.s3compatible-webui = {
      description = "Web UI for browsing/managing s3compatible storage";
      after = [ "garage.service" ];
      requires = [ "garage.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = ''
          ${getExe pkgs.rclone} rcd --rc-web-gui --rc-web-gui-no-open-browser \
            --rc-addr=0.0.0.0:${toString cfg.webUiPort} \
            --rc-user=${cfg.accessKey} --rc-pass=${cfg.secretKey} \
            --config=${rcloneConfig}
        '';
        DynamicUser = true;
        CacheDirectory = "s3compatible-webui";
        Environment = [
          "HOME=/var/cache/s3compatible-webui"
          "XDG_CACHE_HOME=/var/cache/s3compatible-webui"
        ];
        Restart = "on-failure";
      };
    };
  };
}
