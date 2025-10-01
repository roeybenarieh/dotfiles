# My dotfiles

<p align="center">
    <a href="https://nixos.wiki/wiki/Flakes">
        <img src="https://img.shields.io/static/v1?label=Nix Flake&message=check&style=flat&logo=nixos&colorA=24273A&colorB=9173ff&logoColor=CAD3F5">
    </a>
</p>

Desktop wallpaper  
![alt text](./assets/wallpaper.png)

Specs:

- Linux compatible only

## Installation

```bash
git clone git@github.com:roeybenarieh/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
stow .
```

## Installation using home manager(No Nixos)

```bash
# install nix command line
sh <(curl -L https://nixos.org/nix/install) --no-daemon

# install home-manager
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
nix-shell '<home-manager>' -A install # if this command doesn't work, logout and in and try again

# build user configuration
home-manager switch --flake .#roey --extra-experimental-features nix-command --extra-experimental-features flakes
```

## Installation using NixOS

```bash
# install home-manager
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
nix-shell '<home-manager>' -A install # if this command doesn't work, logout and in and try again

# build user configuration
home-manager switch --flake .#roey --extra-experimental-features nix-command --extra-experimental-features flakes


# generate a new hardware-configuration.nix file
nixos-generate-config --dir ./tmp
cp ./tmp/hardware-configuration.nix ./nix/hosts/roey-nixos

# build system configuration
sudo nixos-rebuild switch --show-trace --flake .#roey-nixos

# reboot to make eveything take affect
reboot
```

Some of the things manually needed to be created:

- set up Google-authenticator at ~/.google_authenticator
- set up Qtile Dexcom widgets at ~/.local/state/qtile-config
- set up Neovim at ~/.config/nvim
- set up doh1-autofiller configuration at ~/.config/doh1-autofill/config.json

## TODOES

- install a password manager in all devices and configure it properly
- themes for Firefox
- install and configure Neovim
- configure zsh + tmux
- cleanup docker and zsh configurations
- add power profiles for laptop
- get files from Iphone
- Airdrop support(maybe opendrop)
