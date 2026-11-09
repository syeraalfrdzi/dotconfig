#!/usr/bin/env python3
"""Install configuration symlinks, preserving every replaced file in .backups."""
import argparse
from datetime import datetime
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]


def mappings(home):
    config = home / '.config'
    targets = [
        ('config/nvim-lazyvim', config / 'nvim'),
        ('config/zsh/plugins.zsh', config / 'zsh/plugins.zsh'),
        ('config/gh/config.yml', config / 'gh/config.yml'),
        ('config/posting/config.yaml', config / 'posting/config.yaml'),
        ('config/spicetify/config-xpui.ini', config / 'spicetify/config-xpui.ini'),
        ('config/spicetify/Themes/marketplace/color.ini', config / 'spicetify/Themes/marketplace/color.ini'),
        ('apps/ghostty/config.ghostty', home / 'Library/Application Support/com.mitchellh.ghostty/config.ghostty'),
    ]
    for source in sorted((ROOT / 'home').iterdir()):
        if source.is_file():
            targets.append((str(source.relative_to(ROOT)), home / source.name))
    return targets


def install(home, dry_run=False, config_only=False):
    backup = ROOT / '.backups' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    installed = []
    for relative, target in mappings(home):
        source = ROOT / relative
        if not source.exists():
            continue  # local-only files (e.g. Spicetify's config-xpui.ini) are not in the repo
        if config_only and not target.is_relative_to(home / '.config'):
            continue
        if target.is_symlink() and target.resolve() == source.resolve():
            continue
        print(f'{target} -> {source}')
        if dry_run:
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists() or target.is_symlink():
            saved = backup / target.relative_to(home)
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(target), str(saved))
            installed.append({'target': str(target), 'source': str(source), 'backup': str(saved)})
        else:
            installed.append({'target': str(target), 'source': str(source), 'backup': None})
        target.symlink_to(source, target_is_directory=source.is_dir())
    if installed:
        backup.mkdir(parents=True, exist_ok=True)
        (backup / 'manifest.json').write_text(json.dumps(installed, indent=2) + '\n')
        print(f'Backup dan manifest: {backup}')
    return installed


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--config-only', action='store_true', help='Hanya tautkan file di ~/.config.')
    args = parser.parse_args()
    install(Path.home(), args.dry_run, args.config_only)
