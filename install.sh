#!/bin/zsh
set -euo pipefail
repo_dir=${0:A:h}
cd "$repo_dir"

if [[ ${1:-} == --dry-run ]]; then
  exec python3 scripts/install.py --dry-run
fi

python3 scripts/install.py
git config core.hooksPath scripts
print 'Konfigurasi terpasang. Buka ulang aplikasi dan jalankan exec zsh.'

