bindkey -e

case ${OSTYPE} in
  darwin*)
    export LC_ALL=en_US.UTF-8
    export LANG=en_US.UTF-8
    ;;
  linux*)
    export LC_ALL=en_US.utf8
    export LANG=en_US.utf8
    export LANGUAGE=en_US.utf8
    ;;
esac

# prevent zsh from exit with ctrl-d key
setopt IGNOREEOF
# share history, avoid duplication
setopt share_history
setopt hist_reduce_blanks
setopt hist_ignore_all_dups
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

EDITOR=nvim

setopt auto_pushd
setopt pushd_ignore_dups

# disable lock/unlock with ctrl-s/ctrl-q
setopt no_flow_control

typeset -U path PATH

path=(
  ~/.ghq/bin(N-/)
  ~/.fzf/bin(N-/)
  ~/bin(N-/)
  /usr/local/go/bin(N-/)
  ~/.cargo/bin(N-/)
  ~/.local/bin(N-/)
  ~/.yarn/bin(N-/)
  ~/Library/Python/3.9/bin(N-/)
  ~/.config/yarn/global/node_modules/bin(N-/)
  /usr/local/bin(N-/)
  /usr/bin
  /usr/sbin
  /bin
  /sbin
  /usr/local/sbin(N-/)
  /opt/local/bin(N-/)
  /Library/Apple/usr/bin(N-/)
  $path
)

case ${OSTYPE} in
  darwin*)
    eval "$(/opt/homebrew/bin/brew shellenv)"
    ;;
esac

typeset -U fpath

fpath=(
  /opt/homebrew/share/zsh-completions(N-/)
  /opt/homebrew/share/zsh/site-functions(N-/)
  ~/.config/zsh/zsh-completions(N-/)
  $fpath
)

case ${OSTYPE} in
  darwin*)
    source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    ;;
esac

autoload -Uz compinit; compinit

export GHQ_ROOT="$HOME/.ghq/src"
export GOPATH="$HOME/.ghq"
export GOBIN="$HOME/bin"
export GO11MODULE="auto"

PROMPT='%n@%m:%~$ '
autoload -Uz vcs_info
precmd_vcs_info() { vcs_info }
precmd_functions+=( precmd_vcs_info )
setopt prompt_subst
RPROMPT=\$vcs_info_msg_0_
zstyle ':vcs_info:git:*' formats '%b'

case ${OSTYPE} in
  darwin*)
    if type gls &>/dev/null; then
      alias ls='gls -X -F -T 2 -C --color=auto'
    else
      alias ls='ls -F -C -G'
    fi
    ;;
  linux*)
    alias ls='ls -XFC -T 2 --color=auto'
    ;;
esac


alias ll='ls -l'
alias la='ls -A'
alias lla='ll -A'

alias rm='rm -i'
alias cp='cp -ip'
alias mv='mv -i'

alias gl='git l'
alias gb='git branch -av'
alias gs='git status -sb'
alias gd='git diff'
alias ga='git add -N . && git add -p'
alias gc='git commit -s -v'
alias gp='git push origin'

alias t='tig'
alias ta='tig --all'
alias ts='tig status'

alias v='nvim'
alias vim='nvim'
alias vc='nvim --clean'
alias vimc='nvim --clean'
alias vimdiff='nvim -d'

alias q='goto_repo_root'
function goto_repo_root() {
  if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    cd $(git rev-parse --show-toplevel)
  fi
}

function chdir_parent() {
  echo
  cd ..
  zle accept-line
}
zle -N chdir_parent
bindkey '^u' chdir_parent

function __fzfcmd() {
  [ -n "$TMUX_PANE" ] && { [ "${FZF_TMUX:-0}" != 0 ] || [ -n "$FZF_TMUX_OPTS" ]; } &&
    echo "fzf-tmux ${FZF_TMUX_OPTS:--d${FZF_TMUX_HEIGHT:-40%}} -- " || echo "fzf"
}

function git-repo-cd() {
  local selected_dir=$(ghq list --full-path | \
    FZF_DEFAULT_OPTS='--height 40% --reverse +m' $(__fzfcmd)) 
  local ret=$?
  if [ -z "$selected_dir" ]; then
    zle redisplay
    return 0
  fi
  eval "builtin cd -- ${selected_dir}"
  zle reset-prompt
  return $ret
}
zle -N git-repo-cd
bindkey "^s" git-repo-cd

function history-widget() {
  local selected num
  selected=($(fc -rl 1 | FZF_DEFAULT_OPTS='--height 40% --reverse +m' $(__fzfcmd)))
  local ret=$?
  if [ -n "$selected" ]; then
    num=$selected[1]
    if [ -n "$num" ]; then
      zle vi-fetch-history -n $num
    fi
  fi
  zle reset-prompt
  return $ret
}
zle -N history-widget
bindkey "^r" history-widget

function grep-and-fuzzy-find() {
  local selected_file
  RG_PREFIX='rg -H --column -n -S -uu '
  selected_file=$(FZF_DEFAULT_COMMAND="$RG_PREFIX $LBUFFER" \
    fzf --reverse --disabled \
    --bind "change:reload:sleep 0.1; $RG_PREFIX {q} || true" \
    --bind "alt-enter:unbind(change,alt-enter)+change-prompt(rg>fzf> )+enable-search+clear-query" \
    --prompt 'rg> ' --delimiter : \
    --preview 'bat --color=always --theme="Solarized (dark)" {1} -H {2}' \
    --preview-window 'up,60%,border-bottom,+{2}+3/3,~3')
  local ret=$?
  if [ -n "$selected_file" ]; then
    parts=(${(@s/:/)selected_file})
    if [ -n "$parts[1]" -a -n "$parts[2]" ]; then
      nvim "$parts[1]" "+$parts[2]"
    fi
  fi
  zle reset-prompt
  return $ret
}
zle -N grep-and-fuzzy-find
bindkey "^q" grep-and-fuzzy-find

function custom_tmux_session() {
  if [[ "$#" -ge 1 ]]; then
    ID="$1"
    if [[ -n $TMUX ]]; then
      tmux new-session -d -s"$ID"
      tmux switch-client -t "$ID"
    else
      tmux new-session -s"$ID"
    fi
  else
    ID="`tmux list-sessions 2>/dev/null | $(__fzfcmd) -0 | cut -d: -f1`"
    if [[ -z "$ID" ]]; then
      tmux new-session -s "default"
      return
    fi
    if [[ -n $TMUX ]]; then
      tmux switch-client -t "$ID"
    else
      tmux attach-session -t "$ID"
    fi
  fi
}

if type tmux > /dev/null 2>&1; then
  alias s='custom_tmux_session'
elif type screen > /dev/null 2>&1; then
  alias s='screen'
else
  ;
fi

if [ ! -f ~/.zshrc.zwc -o ~/.zshrc -nt ~/.zshrc.zwc ]; then
  zcompile ~/.zshrc
fi
