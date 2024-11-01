# My dotfiles

Specs:
- Linux compatible only

## Installation

```bash
git clone git@github.com:roeybenarieh/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
stow .
```

## Installation using home manager

```bash
# install nix command line
sh <(curl -L https://nixos.org/nix/install) --no-daemon
# install home-manager
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
nix-shell '<home-manager>' -A install # if this command doesn't work, logout and in and try again
# build the configuration
just rebuild # if you don't have the just CLI: home-manager switch --show-trace --flake . 
```

## TODOES

- install a password manager in all devices and configure it properly
- themes for Firefox
- install and configure Neovim
- configure zsh + tmux
