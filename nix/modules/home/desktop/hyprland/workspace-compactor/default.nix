{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland.workspace-compactor;

  # plonk isn't packaged in nixpkgs: it's a single bash script
  # (github.com/nixfred/plonk), so it's fetched and wrapped here rather
  # than pulled in as a flake input. Pinned to the commit behind the
  # v1.2.6 tag (rather than the tag itself), matching this repo's
  # convention elsewhere of pinning fetched sources to a commit rev.
  plonkVersion = "1.2.6";
  plonkSrc = pkgs.fetchFromGitHub {
    owner = "nixfred";
    repo = "plonk";
    rev = "09ddb2bec88c59ad9841d7239b5a5b537145d056"; # v1.2.6
    hash = "sha256-4Skv5to6RSueIC89/ylJ8Oerb8RHfG5lN7AvSqRjdbk=";
  };
  plonk = pkgs.stdenvNoCC.mkDerivation {
    pname = "plonk";
    version = plonkVersion;
    src = plonkSrc;
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
      runHook preInstall
      install -Dm755 $src/plonk $out/bin/plonk
      wrapProgram $out/bin/plonk \
        --prefix PATH : ${lib.makeBinPath (with pkgs; [ hyprland jq socat libnotify coreutils util-linux ])}
      runHook postInstall
    '';
  };
in
{
  options.${namespace}.desktop.hyprland.workspace-compactor = with types; {
    enable = mkBoolOpt false "Auto-renumber occupied Hyprland workspaces down to 1..N so an empty workspace never leaves a gap before a non-empty one.";
  };

  config = mkIf cfg.enable {
    home.packages = [ plonk ];

    # plonk --watch: whenever a workspace you're not standing on empties out
    # (its last window closes/moves away and Hyprland destroys it), every
    # occupied workspace after it is shifted down to fill the gap. The
    # workspace you're actively on is left alone until you switch away, so
    # it never gets renumbered out from under you.
    systemd.user.services.plonk = {
      Unit = {
        Description = "Auto-collapse Hyprland workspaces to the lowest numbers";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        # renumber=change_id relabels a workspace's existing id in place
        # (hl.dsp.workspace.change_id) instead of the default "move", which
        # moves every window to a newly created workspace and switches focus
        # to it — a real dispatch that fires the windows/workspaces
        # animations and looks like a glitch when it happens automatically
        # right after you've just switched away from the emptied workspace.
        Environment = "PLONK_RENUMBER=change_id";
        ExecStart = "${plonk}/bin/plonk --watch";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
