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
rebuild:
  git add "**.nix" \
  && home-manager switch --show-trace --flake .#roey

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

