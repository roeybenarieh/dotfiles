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
  git add "**.nix" \
  && home-manager switch --show-trace --flake .#roey

[group('nix')]
rebuild-system:
  git add "**.nix" \
  && sudo nixos-rebuild switch --show-trace --flake .#roey-nixos


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


[group('nix')]
rebuild-qtile:
  git add ./.config/qtile/** \
  && git add ./.config/rofi/** \
  && just rebuild-user \
  && qtile cmd-obj -o cmd -f reload_config # reload qtile


# [group('nix')]
# rebuild-nvim:
#   cp ~/.config/nvim/lazyvim.json ./.config/nvim/lazyvim.json \
#   && cp ~/.config/nvim/lazy-lock.json ./.config/nvim/lazy-lock.json \
#   && git add ./.config/nvim/** \
#   && just rebuild-user \


[group('nix')]
rebuild-all:
  just rebuild-system && just rebuild-user && just rebuild-qtile
