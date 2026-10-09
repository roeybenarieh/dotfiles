# AGENTS.md

Project instructions for coding agents working in this repository.

## Privileged commands: VM only

Whenever an agent needs `sudo` or equivalent root privileges, ask the user for approval to use the test VM first (see the testing section below), then run the privileged command **inside the guest**, never on the host. Confirm the command targets the guest before running it. Host `sudo`, `su`, `doas`, `pkexec`, or host-root execution through another tool are not substitutes. If a task genuinely requires host privileges and cannot be validated in the VM, explain the limitation and leave the host operation to the user.

## Overview

NixOS + Home Manager dotfiles using [Nix Flakes](https://nixos.wiki/wiki/Flakes) and [Snowfall Lib](https://snowfall.org/guides/lib/quickstart/) for modular configuration. Namespace: `extra`.

## Common Commands

```bash
just rebuild              # Rebuild and switch NixOS system config + Home Manager (sudo) — user must run this interactively.
just format               # Format all Nix files with treefmt
just update-all-dependencies  # Update flake.lock
just collect-garbage      # Run nix-collect-garbage
just rollback-user        # Interactively roll back to a previous HM generation (fzf)
just debug                # Open nixos-rebuild REPL (press :r to reload)
just show-dependencies    # Visualize package dependency tree (nix-tree)
just show-flake           # Show flake outputs
just copy-existing-nixos-config <system>  # Copy /etc/nixos/* into the repo for a given system
just test-vm              # Ask the user before starting/restarting or using the isolated VM
just test-vm-rebuild      # Rebuild the running VM's config via SSH (after making host changes)
just test-vm-reset        # Destroy the VM disk image and start completely fresh
```

**Important:** Nix Flakes only see tracked files, so stage changes (and `git add` any new files) before building. The `just` recipes stage known paths via `_base_nix_git_stage`; new module files elsewhere need manual staging.

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

**Dry-run before declaring done:** After making any Nix config changes, always run a dry-build to catch evaluation errors before telling the user you're finished:
```bash
git add flake.nix flake.lock && git add ./nix/lib/** && git add ./nix/modules/home/** ./nix/homes/** && git add ./nix/modules/nixos/** ./nix/systems/** && nixos-rebuild dry-build --flake .
```
Fix any errors that appear, then re-run until it succeeds cleanly. Only then tell the user to run `just rebuild` in their terminal (or `! just rebuild` in OpenCode's shell mode).

**Fonts:** When making any font-related changes, run `fc-cache -rf` after rebuilding to refresh the font cache.

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

**Task observer:** Invoke `task-observer` at the start of every session involving tool use or multi-step work.

## Testing in an isolated environment (ask first)

The `test-vm` system (`nix/systems/x86_64-linux/test-vm/`) uses the same desktop modules as the laptop and shares the host `/nix/store` — **nothing is re-downloaded**. It runs headless Hyprland (pixman software rendering, no GPU needed) inside QEMU/KVM and exposes the desktop via `wayvnc` → noVNC.

### When to use a test environment

Ask the user for approval to use the test VM whenever:
- A command requires `sudo` or equivalent root privileges (see "Privileged commands")
- A config change affects a service, daemon, or app that needs to be started to verify
- A GUI feature needs to be visually confirmed (window behaviour, keybindings, app layout)
- The agent needs to click on something to verify it works
- A change might break the desktop or login flow

For unprivileged checks, use the VM only when a dry-build alone cannot confirm correctness.

### VM

Before starting or reusing the VM, explain why it is needed and wait for the user's approval. Once approved, run `just test-vm` from `/home/roey/.dotfiles` if needed and keep it running in a persistent terminal/background session while using the guest. Ask again before restarting or resetting it. If approval is not given, report VM-dependent verification as pending.

After startup (~30–60 s first boot), the terminal prints an info box and holds. Pressing Ctrl-C in that terminal kills the VM and noVNC. Agent workflow:
1. Use `hypruse` to inspect the desktop and open `http://localhost:6080/vnc.html` in a browser.
2. Connect (no VNC password)
3. Use `hypruse` on the host browser window with screenshots, zoom, and focused input to interact with the guest desktop through the noVNC canvas. Confirm the browser window address before sending input; host desktop controls do not directly target guest windows.
4. During an approved VM testing session, edit config files, then run `just test-vm-rebuild`:
   - Stages all nix files, then SSHes into the running VM as root (key-based, no password)
   - Runs `nixos-rebuild switch --flake /dotfiles#test-vm` inside the VM
   - The VM mounts the host dotfiles repo at `/dotfiles` — no copy needed
   - Packages already in the host `/nix/store` are reused instantly
5. Reload the noVNC page or re-check the GUI to verify the change
6. View serial console (boot messages): `! tail -f /tmp/test-vm-console.log`
7. Full reset (destroys disk image): `! just test-vm-reset`

The disk image `test-vm.qcow2` persists between runs in the dotfiles root directory.
