{ namespace, lib, config, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.tailscale;
in
{
  options.${namespace}.tailscale = with types; {
    enable = mkBoolOpt false "Enable Tailscale (private WireGuard mesh VPN). Gives this machine a stable `<machine>.ts.net` hostname reachable from every other device signed into the same tailnet, with no port forwarding or firewall rules needed.";

    authKeyFile = mkOpt (nullOr path) null
      "Path to a file containing a Tailscale auth key, for unattended `tailscale up` (https://tailscale.com/kb/1085/auth-keys). Leave null to authenticate interactively with `sudo tailscale up` after the first rebuild.";

    operator = mkOpt (nullOr str) null
      "Unix username allowed to run `tailscale` subcommands (serve, funnel, status, ...) without sudo (https://tailscale.com/kb/1445/set-operator). Leave null to require sudo for every `tailscale` invocation.";
  };

  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      authKeyFile = cfg.authKeyFile;
      openFirewall = true;
      permitCertUid = cfg.operator;
      extraSetFlags = optional (cfg.operator != null) "--operator=${cfg.operator}";
    };

    programs.chromium.extraOpts.ManagedBookmarks = [{
      name = "tailscale";
      url = "https://console.tailscale.com/admin/machines";
    }];

    # enabled ssh so other
    ${namespace}.ssh = enabled;
  };
}
