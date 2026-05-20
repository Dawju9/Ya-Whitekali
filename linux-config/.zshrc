# ==============================
# KXL SYSTEM - ZSH CORE CONFIG
# ==============================

[ -z "$ZSH_VERSION" ] && return

# ==============================
# SAFETY
# ==============================
setopt NO_NOMATCH
setopt GLOB_DOTS

# ==============================
# HISTORY
# ==============================
HISTSIZE=50000
SAVEHIST=100000

setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS

# ==============================
# COLORS
# ==============================
autoload -Uz colors
colors
setopt PROMPT_SUBST

# ==============================
# COMPINIT
# ==============================
autoload -Uz compinit
compinit

# ==============================
# GIT INFO
# ==============================
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats ' %F{magenta} %b%f'

# ==============================
# PROMPT
# ==============================
PROMPT='%F{cyan} %n%f %F{blue} %m%f %F{yellow} %~%f ${vcs_info_msg_0_} %F{green}❯%f '

# ==============================
# DEFAULTS
# ==============================
export EDITOR=nano

setopt AUTO_CD
setopt CORRECT
setopt INTERACTIVE_COMMENTS

SPROMPT="%F{yellow}➜ Correct '%F{red}%r%F{yellow}' to '%F{green}%R%F{yellow}'? [nyae]: %f"

# ==============================
# KEYBINDINGS
# ==============================
bindkey -e
bindkey '^R' history-incremental-search-backward

autoload -Uz history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey '^P' history-beginning-search-backward-end
bindkey '^N' history-beginning-search-forward-end

# ==============================
# COMPLETION
# ==============================
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ==============================
# ENVIRONMENT
# ==============================
export HIST_STAMPS="yyyy-mm-dd HH:MM"
export OLLAMA_HOST="http://localhost:11434"
export OLLAMA_NUM_CTX=4096
export OLLAMA_MODEL="qwen2.5-coder:1.5b"
export OLLAMA_KEEP_ALIVE=24h
export OLLAMA_NUM_PARALLEL=1
# export GITHUB_TOKEN="your_github_token_here"
# export GITHUB_USER="your_github_username_here"
export PATH="$HOME/.local/bin:$PATH"
export PATH=/root/.opencode/bin:$PATH
export NVM_DIR="$HOME/.nvm"

# ==============================
# PLUGINS
# ==============================
[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && \
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && \
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ==============================
# NVM
# ==============================
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# ==============================
# SOURCE MODULES
# ==============================
source ~/.zsh/commands.sh
source ~/.zsh/welcome.sh

# ==============================
# EXTERNAL
# ==============================
source /Development/scripts/site-status.sh
nvm use default
