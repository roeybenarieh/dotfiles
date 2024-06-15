# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
ZSH_THEME="robbyrussell"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  zsh-autosuggestions web-search fast-syntax-highlighting zsh-autocomplete common-aliases command-not-found colored-man-pages
  git fzf helm tmux oc tmux
  python pip
  nvm
)

# nvm plugin configuration
zstyle ':omz:plugins:nvm' lazy yes # Load nvm lazyly
zstyle ':omz:plugins:nvm' lazy-cmd nvim neovim # load nvm when neovim is loaded

# tmux plugin configuration
ZSH_TMUX_UNICODE=true # enforce utf-8 for showing shell icons
ZSH_TMUX_AUTOSTART=true # start tmux when session start
ZSH_TMUX_FIXTERM=true # set 256-color terminal if supported
ZSH_TMUX_AUTOCONNECT=false # start tmux session every terminal loggin
ZSH_TMUX_CONFIG=$HOME/.config/tmux/tmux.conf


# fzf plugin configuration
# preview fzf files with the bat(batcat) cli
export FZF_CTRL_T_OPTS="--preview 'batcat -n --color=always {}'
  --bind 'ctrl-/:change-preview-window(down|hidden|)'
  --color header:italic
  --header 'CTRL-/ to change preview window'"
export FZF_CTRL_R_OPTS="
  --preview 'echo {}' --preview-window up:3:hidden:wrap
  --bind 'ctrl-/:toggle-preview'
  --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort'
  --color header:italic
  --header 'CTRL=/ to change preview window. CTRL-Y to copy command into clipboard'"
export FZF_ALT_C_OPTS="
  --preview 'tree -C {}'"

# Function to install a oh-my-zhs plugin if it doesn't exist
# Parameters:
#   $1 - resource type, either 'plugins' or 'themes'
#   $2 - resource name
#   $3 - resource installtion url
install_oh_my_zsh_resource_if_not_exists() {
  local resource_type="$1"
  local resource_name="$2"
  local resource_url="$3"
  local oh_my_zsh_resource_dir=${ZSH_CUSTOM:-$ZSH/custom}/$resource_type/$resource_name
  
  # Check if the plugin already exists
  if [ ! -d "$oh_my_zsh_resource_dir" ]; then
    echo "Installing $resource_name of type $resource_type in path: $oh_my_zsh_resource_dir"
    git clone --quiet --depth 1 "$resource_url" "$oh_my_zsh_resource_dir"
  fi
}

# install oh-my-zsh if not exists
[[ -x $HOME/.oh-my-zsh ]] || sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --keep-zshrc # the "" is needed
# install oh-my-zsh theme if not exists
install_oh_my_zsh_resource_if_not_exists "themes" "powerlevel10k" "https://github.com/romkatv/powerlevel10k.git"
# install oh-my-zsh plugins if not exists
install_oh_my_zsh_resource_if_not_exists "plugins" "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"
install_oh_my_zsh_resource_if_not_exists "plugins" "fast-syntax-highlighting" "https://github.com/zdharma-continuum/fast-syntax-highlighting.git"
install_oh_my_zsh_resource_if_not_exists "plugins" "zsh-autocomplete" "https://github.com/marlonrichert/zsh-autocomplete.git"
# install_plugin_if_not_exists "colored-man-pages" "https://github.com/zsh-users/zsh-autosuggestions"
source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias c=clear
alias n=nvim

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
