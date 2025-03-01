# My dotfiles

<p align="center">
    <a href="https://nixos.wiki/wiki/Flakes">
        <img src="https://img.shields.io/static/v1?label=Nix Flake&message=check&style=flat&logo=nixos&colorA=24273A&colorB=9173ff&logoColor=CAD3F5">
    </a>
</p>

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

## TODOES

- install a password manager in all devices and configure it properly
- themes for Firefox
- install and configure Neovim
- configure zsh + tmux
- IMPORTNANT: add CI to make sure no passwords are pushed to remote
- auto enable firefox extensions
- user google authenticator for xrdp
- fix python(pip install doesn't work)
- qtile - start where I left off(reload the previous windows that existed before shutdown)
- qtile - when I click links from apps, that should bring me to firefox, does open the link in firefox but it happens in the backgound(I want it to transfer me to firefox)
- better protection of ssh server connections(currently people brute force trying to get in)
- fix stremio server port(maybe even point it to outside world?)
- enable wake on lan, and make it work threw router
- qtile - some keybindings not working in Hebrew(although they should, like Winkey-w)
- fix virtualbox(or microk8s, I don't remember which one not working)
- make zsh load fast while using more heavy wight plugins like autocompletion etc.
- declerativly configure windows application like tidepool uploader
- service for automaticly fill out "Doh 1"
- install razer keyboard software
- firefox not able to open the folder of a thing downloaded
