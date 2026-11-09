#!/bin/zsh
set -euo pipefail
repo_dir=${0:A:h}
cd "$repo_dir"
if ! (( $+commands[brew] )); then
  print -u2 'Pasang Homebrew dari https://brew.sh, lalu jalankan skrip ini lagi.'
  exit 1
fi
brew bundle --file="$repo_dir/Brewfile"
zsh "$repo_dir/install.sh"

