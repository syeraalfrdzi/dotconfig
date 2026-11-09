# Load after compinit and before zsh-autosuggestions.
if (( $+commands[fzf] )); then
  source <(fzf --zsh)

  if [[ -r ${HOMEBREW_PREFIX:-/opt/homebrew}/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh ]]; then
    zstyle ':completion:*' menu no
    source "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh"
  fi
fi

if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

# Sinkronkan konfigurasi yang dikelola repo dotconfig.
dotconfig() {
  zsh "$HOME/.config/dotconfig/sync.sh" "$@"
}
