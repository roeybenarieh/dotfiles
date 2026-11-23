{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.ocm;
  ocm = pkgs.${namespace}.ocm;

  # Signs this machine in to the Manager with INTERNAL_TOKEN from the env file.
  # The token is piped on stdin so it never appears in the process list. Retries
  # until the Manager answers, then exits (RemainAfterExit).
  loginScript = pkgs.writeShellScript "ocm-login" ''
    set -eu
    token=$(${pkgs.gnused}/bin/sed -n 's/^INTERNAL_TOKEN=//p' ${escapeShellArg cfg.server.envFile})
    [ -n "$token" ] || { echo "no INTERNAL_TOKEN in ${cfg.server.envFile}" >&2; exit 1; }
    for _ in $(seq 1 30); do
      ${pkgs.curl}/bin/curl -fsS -o /dev/null ${escapeShellArg "${cfg.server.url}/api/health"} && break
      sleep 2
    done
    printf '%s\n' "$token" | exec ${ocm}/bin/ocm login ${escapeShellArg cfg.server.url} --name ${escapeShellArg cfg.server.name}
  '';
in
{
  options.${namespace}.ocm = with types; {
    enable = mkBoolOpt false "Install the OpenCode Manager CLI (`ocm`) and its OpenCode TUI plugin, and sign in to the Manager at `server.url`. Use on every client that attaches to an OpenCode Manager.";

    server = {
      name = mkOpt str "server" "Label shown for this Manager in the TUI.";
      url = mkOpt str "http://server:5003" "Base URL of the OpenCode Manager (the web UI address).";
      envFile = mkOpt str "${config.xdg.configHome}/opencode-manager/env" "Runtime file containing INTERNAL_TOKEN, the same value as on the server (`extra.opencode-manager.envFile`). Never stored in the Nix store.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [{
      assertion = config.programs.opencode.enable;
      message = "extra.ocm requires programs.opencode (extra.opencode) for the TUI plugin.";
    }];

    home.packages = [ ocm ];

    # OpenCode 2 loads a local plugin from a directory containing tui.js. The
    # store path avoids a runtime npm install, matching the other plugins.
    programs.opencode.cli.plugins = [ "${ocm}/dist" ];

    systemd.user.services.ocm-login = {
      Unit = {
        Description = "Sign in to OpenCode Manager at ${cfg.server.url}";
        Wants = "network-online.target";
        After = "network-online.target";
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 30;
        ExecStart = "${loginScript}";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
