default:
  @just --list

# base files needed to be staged by git before building something in nix
_base_nix_git_stage:
  git add flake.nix flake.lock && git add ./nix/**

[group('nix')]
format:
  treefmt

[group('nix')]
show-dependencies:
  nix-tree .

[group('nix')]
explore-dependencies output="/tmp/nix-dependency-graph.html":
  #!/usr/bin/env bash
  set -euo pipefail
  nix-store -q --graph /run/current-system "$HOME/.local/state/nix/profiles/home-manager" \
    | python3 scripts/nix-graph-viewer.py {{output}} \
      . "nixosConfigurations.laptop.config.environment.systemPackages,homeConfigurations.roey.config.home.packages" \
      "NixOS=/run/current-system" "Home Manager=$HOME/.local/state/nix/profiles/home-manager"
  xdg-open {{output}}

[group('nix')]
rollback-user:
  bash $(home-manager generations | fzf | awk -F '-> ' '{print $2 "/activate"}')

[group('nix')]
rebuild:
  @just _base_nix_git_stage \
  && sudo nice -19 nixos-rebuild switch --flake .

# Boot the test VM's login screen and desktop via noVNC on localhost:6080.
[group('nix')]
test-vm: _base_nix_git_stage
  #!/usr/bin/env bash
  set -euo pipefail
  vm=$(nix build .#nixosConfigurations.test-vm.config.system.build.vm --no-link --print-out-paths)
  novnc=$(nix build "nixpkgs#novnc" --no-link --print-out-paths)
  "$novnc/bin/novnc" --listen 127.0.0.1:6080 --vnc localhost:5950 >/tmp/test-vm-novnc.log 2>&1 &
  novnc_pid=$!
  trap 'kill "$novnc_pid" 2>/dev/null || true' EXIT
  curl --fail --silent --retry 10 --retry-connrefused --retry-delay 1 \
    http://localhost:6080/vnc.html --output /dev/null
  echo "Connections become available as the VM boots:"
  echo "SSH command:  ssh -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null localhost"
  echo "VNC Browser:  http://localhost:6080/vnc.html"
  echo "Hypruse MCP:  http://localhost:8081/mcp"
  echo "NixOS MCP:    http://localhost:8082/mcp"
  echo "Boot log: tail -f /tmp/test-vm-console.log | Stop: Ctrl-C"
  "$vm/bin/run-test-vm-vm" </dev/null >/tmp/test-vm-console.log 2>&1

# Rebuild the running test VM's config over SSH after making host changes.
[group('nix')]
test-vm-rebuild: _base_nix_git_stage
  ssh -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@localhost \
    "nixos-rebuild switch --flake /dotfiles#test-vm"

# Destroy the test VM's disk image so the next 'just test-vm' starts completely fresh.
[group('nix')]
test-vm-reset:
  rm -f test-vm.qcow2

[group('nix')]
copy-existing-nixos-config system:
  @if [ -d "./nix/systems/x86_64-linux/{{system}}" ]; then \
    cp /etc/nixos/* ./nix/systems/x86_64-linux/{{system}}; \
  else \
    echo "System '{{system}}' does NOT exist nix/systems/x86_64-linux"; \
  fi

[group('nix')]
show-flake:
  nix flake show

[group('nix')]
update-all-dependencies:
  sudo nix flake update && just rebuild && just collect-garbage

  # NOTE: after collecting garbage, I re-fetch the flake to store in order for neovim to not complaint that the flake doesn't exists
[group('nix')]
collect-garbage days="30" home_manager_days="90" nixos_days="90":
  sudo nix-env -p /nix/var/nix/profiles/system --delete-generations {{nixos_days}}d \
  && nix-env -p ~/.local/state/nix/profiles/home-manager --delete-generations {{home_manager_days}}d \
  && nix-collect-garbage --delete-older-than {{days}}d \
  && nix flake prefetch # prefetch-inputs

[group('nix')]
debug:
  echo press ':r' to reload variables \
  && nixos-rebuild repl --flake . 

