#!/bin/zsh
set -euo pipefail
repo_dir=${0:A:h}
cd "$repo_dir"
# Commit timestamps record the local UTC offset; pin it to UTC so history does not reveal the timezone.
export TZ=UTC
git config core.hooksPath scripts
action=${1:-status}

case "$action" in
  status)
    git status --short --branch
    ;;
  push)
    git add --all
    python3 scripts/check-secrets.py
    if ! git diff --cached --quiet; then
      git commit -m "${2:-Sync konfigurasi macOS}"
    fi
    remote_head=$(git ls-remote origin refs/heads/main)
    if [[ -n "$remote_head" ]]; then
      git pull --rebase origin main
    fi
    git push -u origin main
    ;;
  pull)
    if [[ -n $(git status --porcelain) ]]; then
      print -u2 'Ada perubahan lokal. Jalankan dotconfig push dulu atau commit perubahan sebelum pull.'
      exit 1
    fi
    git pull --ff-only origin main
    zsh "$repo_dir/install.sh"
    ;;
  *)
    print -u2 'Pemakaian: dotconfig [status|push [pesan commit]|pull]'
    exit 1
    ;;
esac

