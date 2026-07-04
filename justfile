default:
  @just --list

# base files needed to be staged by git before building something in nix
_base_nix_git_stage:
  git add flake.nix flake.lock && git add ./nix/lib/** \
  && git add ./nix/modules/home/** ./nix/homes/**

[group('nix')]
format:
  treefmt

[group('nix')]
show-dependencies:
  nix-tree .

[group('nix')]
rollback-user:
  bash $(home-manager generations | fzf | awk -F '-> ' '{print $2 "/activate"}')

[group('nix')]
rebuild:
  @just _base_nix_git_stage \
  && git add ./nix/modules/nixos/** ./nix/systems/** \
  && sudo nice -19 nixos-rebuild switch --flake .

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

