{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.alive-on-power;
in
{
  options.${namespace}.alive-on-power = with types; {
    enable = mkBoolOpt false "Inhibit suspend/hibernate on AC power, allowing systemctl -i to override. Locking the screen is unaffected.";
  };

  config = mkIf cfg.enable {
    # A logind sleep inhibitor covers suspend, hibernate, hybrid sleep and
    # suspend-then-hibernate, while still allowing an explicit -i override.
    systemd.services.ac-power-sleep-inhibitor = {
      description = "Inhibit sleep while connected to AC power";
      wantedBy = [ "multi-user.target" ];
      wants = [ "systemd-logind.service" ];
      after = [ "systemd-logind.service" ];
      serviceConfig = {
        Restart = "always";
        RestartSec = 1;
        KillMode = "control-group";
        # This process only holds the inhibitor open; it never polls or wakes
        # periodically. Stopping the service releases the lock.
        ExecCondition = "${pkgs.systemd}/bin/systemd-ac-power";
        ExecStart = concatStringsSep " " [
          "${pkgs.systemd}/bin/systemd-inhibit"
          "--what=sleep"
          "--mode=block"
          "--who=\"AC power\""
          "--why=\"Connected to AC power\""
          "${pkgs.coreutils}/bin/sleep infinity"
        ];
      };
    };

    # Reconcile at boot and on kernel power-supply events. Starting an already
    # running inhibitor is a no-op, so battery updates do not interrupt it.
    systemd.services.ac-power-sleep-inhibitor-update = {
      description = "Update the AC power sleep inhibitor";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-logind.service" ];
      unitConfig.StartLimitIntervalSec = 0;
      serviceConfig.Type = "oneshot";
      script = ''
        if ${pkgs.systemd}/bin/systemd-ac-power; then
          ${pkgs.systemd}/bin/systemctl start ac-power-sleep-inhibitor.service
        else
          ${pkgs.systemd}/bin/systemctl stop ac-power-sleep-inhibitor.service
        fi
      '';
    };

    # --no-block lets udev finish without waiting for the systemd job.
    # Restart queues another check even if the previous check is still running.
    services.udev.extraRules = ''
      SUBSYSTEM=="power_supply", ACTION=="add|change|remove", RUN+="${pkgs.systemd}/bin/systemctl --no-block restart ac-power-sleep-inhibitor-update.service"
    '';
  };
}
