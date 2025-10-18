{ namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.security;
in
{
  options.${namespace}.security = with types; {
    enable = mkBoolOpt false "Whether or not to enable security related protection.";
  };

  config = mkIf cfg.enable {
    services.fail2ban = {
      enable = true;
      bantime-increment = enabled;
    };
  };
}
