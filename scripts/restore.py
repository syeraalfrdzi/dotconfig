#!/usr/bin/env python3
"""Restore one installation backup without deleting newer configuration files."""
import argparse
import json
from pathlib import Path
import shutil

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('backup', type=Path, help='Folder backup yang berisi manifest.json.')
args = parser.parse_args()
entries = json.loads((args.backup / 'manifest.json').read_text())
for item in reversed(entries):
    target = Path(item['target'])
    source = Path(item['source'])
    saved = Path(item['backup']) if item['backup'] else None
    if not target.is_symlink() or target.resolve() != source.resolve():
        print(f'Dilewati karena sudah berubah: {target}')
        continue
    target.unlink()
    if saved and (saved.exists() or saved.is_symlink()):
        shutil.move(str(saved), str(target))
    print(f'Dipulihkan: {target}')

