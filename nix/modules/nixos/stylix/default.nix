{ namespace, lib, config, inputs, pkgs, ... }:

with lib;
with lib.${namespace};

let
  cfg = config.${namespace}.stylix;
in
{
  options.${namespace}.stylix = with types; {
    enable = mkBoolOpt false "Whether or not to enable system-level Stylix configuration.";
  };

  config = mkIf cfg.enable {
    stylix = {
      enable = true;
      image = "${inputs.assets}/theme.png";
      # HM Stylix is configured directly; prevent auto-injection into HM users
      # which would cause base16 to be set twice (read-only conflict)
      homeManagerIntegration.autoImport = false;
      cursor = {
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Ice";
        size = 24;
      };
    };

    # Make the cursor theme available system-wide so services running as
    # system users can find it in XDG_DATA_DIRS
    environment.systemPackages = [ pkgs.bibata-cursors ];
  };
}
