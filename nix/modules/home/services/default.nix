{ namespace, lib, config, system, inputs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services;
  doh1_autofill_pacage = inputs.doh1-autofill.packages.${system}.default;
  doh1_service_name = "doh1-autofill";
in
{
  options.${namespace}.services = with types; {
    enable = mkBoolOpt false "Whether or not to install custom services.";
  };

  config = mkIf cfg.enable {
    systemd.user = {
      # get service status: systemctl status --user doh1-autofill
      # get service logs: journalctl --user -u doh1-autofill
      # these configurations automaticly gets converted from nix to normal systemd service toml configuration
      services.${doh1_service_name} = {
        Service = {
          ExecStart = getExe doh1_autofill_pacage;
          StandardOutput = "journal";
          StandardError = "journal";
          # restart policies
          Restart = "on-failure";
          RestartSec = "1h"; # restart service after 1 hour
          StartLimitBurst = 3; # Allow 3
        };
        Unit.Description = "Automatically fill out doh1";
      };
      # get task status: systemctl status --user doh1-autofill-task.timer
      # timer deciding when to trigger the service
      timers."${doh1_service_name}-task" = {
        Timer = {
          OnCalendar = "Fri,Sat *-*-* 17:00:00"; # Runs at 17:00 on Fridays and Saturdays
          Persistent = true; # Run missed tasks when the system is next started
          Unit = "${doh1_service_name}.service";
        };
        Unit.Description = "Timer for ${doh1_service_name} service";
      };
    };
  };
}
