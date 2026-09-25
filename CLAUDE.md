# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

NixOS + Home Manager dotfiles using [Nix Flakes](https://nixos.wiki/wiki/Flakes) and [Snowfall Lib](https://snowfall.org/guides/lib/quickstart/) for modular configuration. Namespace: `extra`.

## Common Commands

All build commands require uncommitted changes to be staged first (handled automatically by the `just` recipes via `_base_nix_git_stage`).

```bash
just rebuild              # Rebuild and switch NixOS system config + Home Manager (sudo) — requires interactive sudo, so Claude cannot run this. Always tell the user to run `! just rebuild` in their terminal instead.
just format               # Format all Nix files with treefmt
just update-all-dependencies  # Update flake.lock
just collect-garbage      # Run nix-collect-garbage
just rollback-user        # Interactively roll back to a previous HM generation (fzf)
just debug                # Open nixos-rebuild REPL (press :r to reload)
just show-dependencies    # Visualize package dependency tree (nix-tree)
just show-flake           # Show flake outputs
just copy-existing-nixos-config <system>  # Copy /etc/nixos/* into the repo for a given system
just test-vm              # Build and start a QEMU VM for isolated desktop testing; exposes Hyprland via noVNC (user must run)
just test-vm-rebuild      # Rebuild the running VM's config via SSH (after making host changes)
just test-vm-reset        # Destroy the VM disk image and start completely fresh
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

**Diagnosing problems:** When the user reports a computer problem, first read the relevant NixOS and Home Manager configuration files (`nix/systems/`, `nix/homes/`, `nix/modules/`) to see what modules are currently enabled, then use that context to diagnose the issue. Do not suggest causes or fixes without first understanding what's actually running.

**Dry-run before declaring done:** After making any Nix config changes, always run a dry-build to catch evaluation errors before telling the user you're finished:
```bash
git add flake.nix flake.lock && git add ./nix/lib/** && git add ./nix/modules/home/** ./nix/homes/** && git add ./nix/modules/nixos/** ./nix/systems/** && nixos-rebuild dry-build --flake .
```
Fix any errors that appear, then re-run until it succeeds cleanly. Only then tell the user to run `! just rebuild`.

**Verify changes before finishing:** After making a config change and rebuilding, test that it actually works before declaring the task done. Don't rely solely on the config parsing correctly — test the behavior. For GUI/desktop changes (a window, keybinding, app layout, or other visual/interactive behavior), use the `hypruse` MCP to drive and inspect the live desktop before telling the user you're done.

**Fonts:** When making any font-related changes, run `fc-cache -rf` after rebuilding to refresh the font cache.

**Prefer native NixOS/Home Manager options:** Before writing a manual solution (custom `systemd.user.services`, shell scripts, raw package installs), check whether a native `services.*` or `programs.*` option already exists in NixOS or Home Manager. Use `man home-configuration.nix` or the NixOS module search to verify.

**Finding a NixOS module's source in the store:** Use `nix eval` to get the declaration path, then read it directly — never use `find /nix/store`:
```bash
# Get the .nix file path where an option is declared
nix eval .#nixosConfigurations.<system>.options.<option.path>.enable.declarations
# Example:
nix eval .#nixosConfigurations.laptop.options.services.displayManager.plasma-login-manager.enable.declarations
# → [ "/nix/store/…-source/nixos/modules/services/display-managers/plasma-login-manager.nix" ]
# Then read the file at that path to see all available options and config keys
```
To find the built package output (for inspecting shipped config files, man pages, etc.):
```bash
nix build .#nixosConfigurations.<system>.config.services.<name>.package --no-link --print-out-paths
```

**Task observer:** At the start of every session involving tool use or multi-step work, invoke the `task-observer` skill (One Skill to Rule Them All). It monitors the session for skill improvement opportunities and correction patterns. Ask "Any observations logged?" at the end of each session.

## Testing in an isolated environment (ask the user to run)

The test VM uses the same desktop modules as the laptop and shares the host `/nix/store` — **nothing is re-downloaded**. Hyprland runs inside QEMU/KVM with a headless wlroots backend (no GPU required).

### When Claude should ask for a test environment

Ask the user to run `! just test-vm` whenever:
- A config change affects a service, daemon, or app that needs to be started to verify
- A GUI feature needs to be visually confirmed (window behaviour, keybindings, app layout)
- Claude needs to click on something to verify it works
- A change might break the desktop or login flow

Do **not** ask unless a dry-build alone cannot confirm correctness.

### VM

The `test-vm` system (`nix/systems/x86_64-linux/test-vm/`) runs headless Hyprland (pixman software rendering, no GPU needed) inside QEMU/KVM and exposes the desktop via `wayvnc` → noVNC.

Tell the user: `! just test-vm`

After startup (~30–60 s first boot), the terminal prints an info box and holds. Pressing Ctrl-C in the user's terminal kills the VM and noVNC. Claude's workflow:
1. Invoke the `claude-in-chrome` skill, then open `http://localhost:6080/vnc.html`
2. Connect (no VNC password)
3. Use `mcp__claude-in-chrome__computer` to click and type anywhere in the desktop
4. Edit config files, then run `just test-vm-rebuild` (no user action needed — Claude can run this directly):
   - Stages all nix files, then SSHes into the running VM as root (key-based, no password)
   - Runs `nixos-rebuild switch --flake /dotfiles#test-vm` inside the VM
   - The VM mounts the host dotfiles repo at `/dotfiles` — no copy needed
   - Packages already in the host `/nix/store` are reused instantly
5. Reload the noVNC page or re-check the GUI to verify the change
6. View serial console (boot messages): `! tail -f /tmp/test-vm-console.log`
7. Full reset (destroys disk image): `! just test-vm-reset`

The disk image `test-vm.qcow2` persists between runs in the dotfiles root directory.
