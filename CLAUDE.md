# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

NixOS + Home Manager dotfiles using [Nix Flakes](https://nixos.wiki/wiki/Flakes) and [Snowfall Lib](https://snowfall.org/guides/lib/quickstart/) for modular configuration. Namespace: `extra`.

## Common Commands

All build commands require uncommitted changes to be staged first (handled automatically by the `just` recipes via `_base_nix_git_stage`).

```bash
just rebuild              # Rebuild and switch NixOS system config + Home Manager (sudo)
just format               # Format all Nix files with treefmt
just update-all-dependencies  # Update flake.lock
just collect-garbage      # Run nix-collect-garbage
just rollback-user        # Interactively roll back to a previous HM generation (fzf)
just debug                # Open nixos-rebuild REPL (press :r to reload)
just show-dependencies    # Visualize package dependency tree (nix-tree)
just show-flake           # Show flake outputs
just copy-existing-nixos-config <system>  # Copy /etc/nixos/* into the repo for a given system
```

**Important:** New files must be `git add`-ed before rebuilding, because Nix Flakes only sees tracked files. The just recipes handle this for known paths, but any new module files need to be staged manually first.

## Architecture

### Directory Layout

```
nix/
├── flake.nix           # Flake definition, all external inputs declared here
├── lib/module/         # Shared helper functions (mkOpt, mkBoolOpt, enabled, disabled, etc.)
├── homes/x86_64-linux/roey/  # Home Manager entry point
├── systems/x86_64-linux/     # NixOS system configurations (laptop, home-computer)
└── modules/
    ├── home/           # Home Manager modules (per-user config)
    └── nixos/          # NixOS modules (system-level config)
```

### Snowfall Lib Convention

Snowfall auto-discovers modules, homes, and systems by directory structure — no manual imports needed. Every module receives `{ namespace, lib, config, pkgs, ... }` and follows this pattern:

```nix
{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};  # brings mkBoolOpt, enabled, disabled, etc. into scope
let
  cfg = config.${namespace}.<module-name>;
in
{
  options.${namespace}.<module-name> = with types; {
    enable = mkBoolOpt false "Enable <module-name>.";
  };

  config = mkIf cfg.enable {
    # ...
  };
}
```

Options are exposed under `extra.<module-name>` and enabled in `nix/homes/` or `nix/systems/`.

### Key Lib Helpers (`nix/lib/module/`)

- `mkOpt type default desc` / `mkOpt' type default desc` — generic option
- `mkBoolOpt default desc` / `mkBoolOpt'` — boolean option
- `mkStrOpt`, `mkIntOpt`, `mkListOpt` — typed variants
- `enabled` / `disabled` — shorthand for `{ enable = true/false; }`

### Styling

[Stylix](https://stylix.danth.me/) provides unified theming. Stylix configuration lives in `nix/modules/home/stylix/`. Do not hardcode colors or fonts in individual modules; use Stylix theme variables instead.

### Notable Flake Inputs

| Input | Purpose |
|---|---|
| `nixpkgs` (master) | Stable packages |
| `nixpkgs-unstable` | Bleeding-edge packages |
| `home-manager` | User-level config |
| `stylix` | Unified theming |
| `spicetify-nix` | Spotify customization |
| `nur` | Nix User Repository |
| `claude-desktop` | Claude Desktop app |
| `grafana-dashboards` | GitLab Grafana dashboards |

### CI

GitHub Actions runs on push/PR: flake lock staleness check, git-leaks secret scanning, Nix formatting check (`treefmt`), and FlakHub publishing.

## Workflow Guidelines

**Verify changes before finishing:** After making a config change and rebuilding, test that it actually works before declaring the task done. For GUI/desktop changes, use `xdotool` and rofi's `-dmenu` mode (or equivalent) to verify behavior programmatically, or ask the user to confirm. Don't rely solely on the config parsing correctly — test the behavior.

**Fonts:** When making any font-related changes, run `fc-cache -rf` after rebuilding to refresh the font cache.
