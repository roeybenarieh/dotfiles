{ ... }:

{
  imports = [ ./configuration.nix ];

  # FIX: disable user home manager integration, otherwiser there are errors
  snowfallorg.users.roey = {
    home.enable = false;
  };
  # environment.systemPackages = with pkgs; [ ];
}
