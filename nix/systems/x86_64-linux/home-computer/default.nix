{ ... }:

{
  imports = [ ./configuration.nix ./hardware-configuration.nix ];

  # FIX: disable user home manager integration, otherwiser there are errors
  snowfallorg.users.roey = {
    home.enable = false;
  };
}
