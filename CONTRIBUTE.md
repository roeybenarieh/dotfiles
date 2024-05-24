# Contribute

## using stow

Common usage:

```bash
# create symlinks to files in current directory to parent folder:
stow .
# change stow directory to use the parent file as the wanted file
stow --adopt .
```

resources:  
[stow](https://www.gnu.org/software/stow/)  
[Dreams of Autonomy video](https://youtu.be/y6XCebnB9gs?si=cfg86j-SpSyyvb-p)

## use git subtrees

Currently the maintained git subtrees are: `oh-my-tmux`  
Common usage:

```bash
# create a git subtree
cd ~/dotfiles
git remote add -f oh-my-tmux git@github.com:gpakosz/.tmux.git
git subtree add --prefix <directory to put the repo at> <repo remote> <branch name> --squash

# update a git subtree
git fetch <repo remote> <branch name>
git subtree pull --prefix <directory to put the repo at> <repo remote> <branch name> --squash
```

resources:  
[git subtree](https://www.atlassian.com/git/tutorials/git-subtree)

## general resources

[nix with dotfiles](https://github.com/hlissner/dotfiles)
