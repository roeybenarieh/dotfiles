{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.claude;

  taskObserverSrc = pkgs.fetchFromGitHub {
    owner = "rebelytics";
    repo = "one-skill-to-rule-them-all";
    rev = "281f13466cd3a73e9ebc9d210907748e1941a3dd";
    hash = "sha256-VdK06HjwFWqAmFcN6xG11fH4D2gnZy91SmXVFFrmLXQ=";
  };
in
{
  options.${namespace}.claude = with types; {
    enable = mkBoolOpt false "Whether or not to enable claude-desktop.";
  };

  config = mkIf cfg.enable {
    home.shellAliases.claude = "claude --permission-mode auto";

    # TODO: you programs.claude-code instead
    home.packages = with pkgs; [
      claude-desktop-fhs # claude desktop app
      claude-code # cli
      sox # for using voice

      # MCP related
      nodejs # needed for some MCPs
      pyright # needed in non-pycharm environments for python analytics using LSP
      gh # needed for interacting with github
    ];

    # task-observer meta-skill: watches sessions and improves the skill library over time
    home.file.".claude/skills/task-observer/SKILL.md".source = "${taskObserverSrc}/SKILL.md";
    home.file.".claude/skills/task-observer/references/environments.md".source = "${taskObserverSrc}/references/environments.md";
    home.file.".claude/skills/task-observer/references/skill-authoring.md".source = "${taskObserverSrc}/references/skill-authoring.md";
    home.file.".claude/skills/task-observer/references/weekly-review.md".source = "${taskObserverSrc}/references/weekly-review.md";

    programs.chromium = {
      extensions = [ "fcoeoabgfenejglbffodgkkbkcdhcgfn" ]; # claude chrome extension
      commandLineArgs = [
        "--remote-debugging-port=9222" # enable Chrome's remote debugging API - used by claude sometimes
      ];
    };
  };
}
