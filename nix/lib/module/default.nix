{ lib, ... }:

with lib;
rec {
  ## Create a NixOS module option.
  ##
  ## ```nix
  ## lib.mkOpt nixpkgs.lib.types.str "My default" "Description of my option."
  ## ```
  ##
  #@ Type -> Any -> String
  mkOpt =
    type: default: description:
    mkOption { inherit type default description; };

  ## Create a NixOS module option without a description.
  ##
  ## ```nix
  ## lib.mkOpt' nixpkgs.lib.types.str "My default"
  ## ```
  ##
  #@ Type -> Any -> String
  mkOpt' = type: default: mkOpt type default null;

  ## Create a boolean NixOS module option.
  ##
  ## ```nix
  ## lib.mkBoolOpt true "Description of my option."
  ## ```
  ##
  #@ Type -> Any -> String
  mkBoolOpt = mkOpt types.bool;

  ## Create a boolean NixOS module option without a description.
  ##
  ## ```nix
  ## lib.mkBoolOpt true
  ## ```
  ##
  #@ Type -> Any -> String
  mkBoolOpt' = mkOpt' types.bool;

  ## Create an integer NixOS module option.
  ##
  ## ```nix
  ## lib.mkIntOpt 123 "Description of my option."
  ## ```
  ##
  #@ Type -> Any -> String
  mkIntOpt = mkOpt types.int;

  ## Create an integer NixOS module option without a description.
  ##
  ## ```nix
  ## lib.mkIntOpt 123
  ## ```
  ##
  #@ Type -> Any -> String
  mkIntOpt' = mkOpt' types.int;

  ## Create a string NixOS module option.
  ##
  ## ```nix
  ## lib.mkstrOpt "text" "Description of my option."
  ## ```
  ##
  #@ Type -> Any -> String
  mkstrOpt = mkOpt types.str;

  ## Create a string NixOS module option without a description.
  ##
  ## ```nix
  ## lib.mkstrOpt "text"
  ## ```
  ##
  #@ Type -> Any -> String
  mkstrOpt' = mkOpt' types.str;

  enabled = {
    ## Quickly enable an option.
    ##
    ## ```nix
    ## services.nginx = enabled;
    ## ```
    ##
    #@ true
    enable = true;
  };

  disabled = {
    ## Quickly disable an option.
    ##
    ## ```nix
    ## services.nginx = enabled;
    ## ```
    ##
    #@ false
    enable = false;
  };
}
