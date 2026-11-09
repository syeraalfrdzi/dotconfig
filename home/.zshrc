# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[[ ! -r "${HOMEBREW_PREFIX:-/opt/homebrew}/share/powerlevel10k/powerlevel10k.zsh-theme" ]] || source "${HOMEBREW_PREFIX:-/opt/homebrew}/share/powerlevel10k/powerlevel10k.zsh-theme"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# >>> Zsh autocomplete >>>
# Homebrew command completions and an interactive Tab selection menu.
typeset -U fpath
[[ ! -d ${HOMEBREW_PREFIX:-/opt/homebrew}/share/zsh/site-functions ]] || fpath=(${HOMEBREW_PREFIX:-/opt/homebrew}/share/zsh/site-functions $fpath)
autoload -Uz compinit
zmodload zsh/complist
compinit -i
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
bindkey '^I' expand-or-complete

# >>> zoxide, fzf, fzf-tab >>>
[[ ! -r "$HOME/.config/zsh/plugins.zsh" ]] || source "$HOME/.config/zsh/plugins.zsh"
# <<< zoxide, fzf, fzf-tab <<<

# Keep command history for suggestions across shell sessions.
HISTFILE=${HISTFILE:-$HOME/.zsh_history}
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY HIST_IGNORE_SPACE HIST_EXPIRE_DUPS_FIRST

# Suggest from history first, then from the completion system.
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
if [[ -r ${HOMEBREW_PREFIX:-/opt/homebrew}/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source ${HOMEBREW_PREFIX:-/opt/homebrew}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
# <<< Zsh autocomplete <<<
alias ls='lsd --icon always'

# Pengaturan khusus Mac ini, tidak masuk Git.
[[ ! -r "$HOME/.zshrc.local" ]] || source "$HOME/.zshrc.local"

# opencode
export PATH="$HOME/.opencode/bin:$PATH"


# Added by Antigravity CLI installer
export PATH="$HOME/.local/bin:$PATH"

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

