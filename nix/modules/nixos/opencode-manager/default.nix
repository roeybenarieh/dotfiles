{ pkgs, namespace, lib, config, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.opencode-manager;
  owner = config.users.users.${cfg.user};
  dataDir = "/var/lib/opencode-manager";
  dbPath = "${dataDir}/data/opencode.db";
  sqlite = "${pkgs.sqlite}/bin/sqlite3";

  # The Manager keeps its internal token (used by `ocm` clients) in app_secrets
  # and generates a random one on first use. Write the shared token from
  # the INTERNAL_TOKEN in cfg.envFile into that row, so clients can be configured declaratively.
  # Restart the container only when the value actually changes.
  seedToken = pkgs.writeShellScript "opencode-manager-token" ''
    set -eu
    token=$(${pkgs.gnused}/bin/sed -n 's/^INTERNAL_TOKEN=//p' ${escapeShellArg cfg.envFile})
    [ -n "$token" ] || { echo "no INTERNAL_TOKEN in ${cfg.envFile}" >&2; exit 1; }

    # The Manager creates app_secrets when it runs its migrations on first start.
    # Probe read-only so this never creates an empty database file.
    for _ in $(seq 1 60); do
      ${sqlite} -readonly ${dbPath} "SELECT 1 FROM app_secrets LIMIT 1;" >/dev/null 2>&1 && break
      sleep 2
    done

    current=$(${sqlite} ${dbPath} "SELECT value FROM app_secrets WHERE key = 'internal_token';")
    [ "$current" = "$token" ] && exit 0

    now=$(${pkgs.coreutils}/bin/date +%s%3N)
    ${sqlite} ${dbPath} "INSERT INTO app_secrets (key, value, created_at, updated_at) VALUES ('internal_token', '$token', $now, $now) ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at;"
    ${pkgs.systemd}/bin/systemctl restart docker-opencode-manager.service
  '';

  # Registers `cfg.servers` through the Manager's own admin sign-in and REST
  # API, so the Manager encrypts each stored password itself. Names that are
  # already registered are skipped, which keeps the unit idempotent.
  registerServers = pkgs.writeShellScript "opencode-manager-servers" ''
    set -eu
    base=http://localhost:${toString cfg.port}
    jar=$(${pkgs.coreutils}/bin/mktemp)
    trap '${pkgs.coreutils}/bin/rm -f "$jar"' EXIT

    admin_email=$(${pkgs.gnused}/bin/sed -n 's/^ADMIN_EMAIL=//p' ${escapeShellArg cfg.envFile})
    admin_password=$(${pkgs.gnused}/bin/sed -n 's/^ADMIN_PASSWORD=//p' ${escapeShellArg cfg.envFile})

    for _ in $(seq 1 60); do
      ${pkgs.curl}/bin/curl -fsS -o /dev/null "$base/api/health" && break
      sleep 2
    done

    ${pkgs.jq}/bin/jq -n --arg e "$admin_email" --arg p "$admin_password" '{email: $e, password: $p}' \
      | ${pkgs.curl}/bin/curl -fsS -o /dev/null -c "$jar" -H 'Content-Type: application/json' -H "Origin: $base" \
          --data @- "$base/api/auth/sign-in/email"

    existing=$(${pkgs.curl}/bin/curl -fsS -b "$jar" "$base/api/opencode-servers")
    ${concatMapStringsSep "\n" (server: ''
      if printf '%s' "$existing" | ${pkgs.jq}/bin/jq -e --arg n ${escapeShellArg server.name} '.servers | any(.name == $n)' >/dev/null; then
        echo "OpenCode server ${server.name} is already registered"
      else
        ${pkgs.jq}/bin/jq -n \
          --arg n ${escapeShellArg server.name} \
          --arg u ${escapeShellArg server.url} \
          --arg s ${escapeShellArg server.username} \
          --rawfile p ${escapeShellArg server.passwordFile} \
          '{name: $n, baseUrl: $u, username: $s, password: ($p | rtrimstr("\n")), enabled: true}' \
          | ${pkgs.curl}/bin/curl -fsS -o /dev/null -b "$jar" -H 'Content-Type: application/json' -H "Origin: $base" \
              --data @- "$base/api/opencode-servers"
      fi
    '') cfg.servers}
  '';
in
{
  options.${namespace}.opencode-manager = with types; {
    enable = mkBoolOpt false "Run OpenCode Manager (Docker) and its `opencode serve` on this machine. Reachable on the Tailscale interface only. Clients connect to it; they do not run their own server.";

    image = mkOpt str "ghcr.io/chriswritescode-dev/opencode-manager:latest" "OpenCode Manager container image. Pin a digest once a release is chosen.";

    user = mkOpt str "remote" "User that owns the Manager data directories and whose uid/gid the container runs as (PUID/PGID).";

    port = mkOpt port 5003 "Port OpenCode Manager listens on.";

    trustedOrigins = mkOpt (listOf str) [ "http://localhost:5003" ] "Browser origins allowed to use OpenCode Manager (AUTH_TRUSTED_ORIGINS). Add every address you open the web UI from.";

    envFile = mkOpt str "/home/remote/.config/opencode-manager/env" "Runtime file with ADMIN_EMAIL, ADMIN_PASSWORD and INTERNAL_TOKEN (the token shared with clients, `extra.ocm.server.envFile`). Read at container start and at boot; never stored in the Nix store.";

    servers = mkOpt (listOf (submodule {
      options = {
        name = mkOpt str "" "Label shown for this OpenCode server in the Manager.";
        url = mkOpt str "" "Base URL the Manager uses to reach the OpenCode server (e.g. http://100.x.y.z:4096).";
        username = mkOpt str "opencode" "Basic-auth username of the OpenCode server.";
        passwordFile = mkOpt str "" "File containing only the OpenCode server password (the same value as its OPENCODE_SERVER_PASSWORD). Never stored in the Nix store.";
      };
    })) [ ] "OpenCode servers on other machines that the Manager registers at startup. Registration is skipped when a server with the same name already exists.";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = config.services.tailscale.enable;
          message = "extra.opencode-manager requires extra.tailscale.enable (the port is opened on tailscale0 only).";
        }
        {
          assertion = owner.uid != null;
          message = "extra.opencode-manager.user (${cfg.user}) must have a fixed uid, used as PUID.";
        }
      ];

      networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [ cfg.port ];

      virtualisation.docker.enable = true;
      virtualisation.oci-containers.backend = "docker";
      virtualisation.oci-containers.containers.opencode-manager = {
        image = cfg.image;
        # Host networking so the tailscale0 firewall rule above applies.
        # Docker's published ports bypass networking.firewall.
        extraOptions = [ "--network=host" ];
        environment = {
          HOST = "0.0.0.0";
          PORT = toString cfg.port;
          NODE_ENV = "production";
          PUID = toString owner.uid;
          # The image already has a group with gid 100 ("users"), so the Manager
          # refuses PGID 100. 1000 is the image's own group, as in upstream compose.
          PGID = "1000";
          AUTH_TRUSTED_ORIGINS = concatStringsSep "," cfg.trustedOrigins;
          # Served over plain http on the tailnet. Secure cookies are dropped by
          # the browser over http, so sign-in appears to succeed and nothing sticks.
          AUTH_SECURE_COOKIES = "false";
          WORKSPACE_PATH = "/workspace";
          DATABASE_PATH = "/app/data/opencode.db";
        };
        environmentFiles = [ cfg.envFile ];
        volumes = [
          "${dataDir}/workspace:/workspace"
          "${dataDir}/data:/app/data"
          "${dataDir}/bin:/home/node/.opencode/bin"
        ];
      };

      systemd.services.opencode-manager-token = {
        description = "Write the shared OpenCode Manager internal token";
        after = [ "docker-opencode-manager.service" ];
        requires = [ "docker-opencode-manager.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${seedToken}";
        };
      };

      systemd.services.opencode-manager-servers = mkIf (cfg.servers != [ ]) {
        description = "Register OpenCode servers with OpenCode Manager";
        after = [ "docker-opencode-manager.service" "opencode-manager-token.service" ];
        requires = [ "docker-opencode-manager.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${registerServers}";
        };
      };

      systemd.tmpfiles.rules = [
        "d ${dataDir} 0750 ${cfg.user} ${owner.group} -"
        "d ${dataDir}/workspace 0750 ${cfg.user} ${owner.group} -"
        "d ${dataDir}/data 0750 ${cfg.user} ${owner.group} -"
        "d ${dataDir}/bin 0750 ${cfg.user} ${owner.group} -"
      ];
    }
  ]);
}
