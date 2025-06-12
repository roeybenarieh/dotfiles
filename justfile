default:
  @just --list

[group('stow')]
deploy:
  stow .

[group('stow')]
undeploy:
  stow --delete .

[group('nix')]
format:
  treefmt

[group('nix')]
rebuild-user:
  git add ./nix/modules/home/** \
  && git add ./nix/homes/** \
  && home-manager switch --flake .

[group('nix')]
rollback-user:
  bash $(home-manager generations | fzf | awk -F '-> ' '{print $2 "/activate"}')

[group('nix')]
rebuild-system:
  git add ./nix/modules/nixos/** \
  && git add ./nix/systems/** \
  && sudo nixos-rebuild switch --flake .

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
list-builds:
  home-manager generations \
  && echo "IMPORTANT:" \
  && echo "run the /nix/store/<hash>-home-manager-generation/activate script to return to that generation"

[group('nix')]
update-dependencies:
  nix flake update

[group('nix')]
collect-garbage:
  nix-collect-garbage


# [group('nix')]
# rebuild-nvim:
#   cp ~/.config/nvim/lazyvim.json ./.config/nvim/lazyvim.json \
#   && cp ~/.config/nvim/lazy-lock.json ./.config/nvim/lazy-lock.json \
#   && git add ./.config/nvim/** \
#   && just rebuild-user \


[group('nix')]
rebuild-all:
  just rebuild-system && just rebuild-user
