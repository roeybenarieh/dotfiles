{ namespace, lib, config, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.opencode-serve;
in
{
  options.${namespace}.opencode-serve = with types; {
    enable = mkBoolOpt false "Open the port of `extra.opencode.server` on the Tailscale interface only, so remote OpenCode clients (OpenCode Manager) can attach.";

    port = mkOpt port 4096 "Port of `extra.opencode.server.port` to open on Tailscale. Must match the Home Manager setting.";
  };

  config = mkIf cfg.enable {
    assertions = [{
      assertion = config.services.tailscale.enable;
      message = "extra.opencode-serve requires extra.tailscale.enable (the port is opened on tailscale0 only).";
    }];

    networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [ cfg.port ];
  };
}
