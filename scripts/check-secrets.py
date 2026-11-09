#!/usr/bin/env python3
"""Reject credentials and personal data from files about to be committed.

Besides credential patterns, this blocks this machine's own git identity (name/email from the
global config, including ~/.gitconfig.local) and decimal latitude/longitude assignments, so a
backup of a live config file cannot publish who or where the owner is.
"""
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
pattern = re.compile(
    r'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}'
    r'|sk-(?:proj-)?[A-Za-z0-9_-]{30,}'
    r'|AKIA[A-Z0-9]{16}'
    r'|-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----'
    r'|(?i:bearer)\s+[A-Za-z0-9._-]{25,}'
    r'|(?i:access_token|refresh_token|api_key|client_secret|password)["\x27]?\s*[:=]\s*["\x27][^"\x27\n]{8,}["\x27]'
)
coordinates = re.compile(r'(?i)\b(?:lat(?:itude)?|lng|lon(?:gitude)?)["\x27]?\s*[:=]\s*-?\d{1,3}\.\d{4,}')


def own_identity():
    values = []
    for key in ('user.name', 'user.email'):
        found = subprocess.run(['git', 'config', '--global', '--includes', '--get', key],
                               capture_output=True, text=True).stdout.strip()
        if len(found) >= 4:
            values.append(found.lower())
    return values


identity = own_identity()
paths = subprocess.check_output(['git', 'diff', '--cached', '--name-only', '--diff-filter=ACM', '-z'], cwd=root).split(b'\0')
failed = []
for raw in paths:
    if not raw:
        continue
    name = raw.decode()
    # Scan the staged bytes, including a file changed after git add.
    contents = subprocess.check_output(['git', 'show', ':' + name], cwd=root).decode('utf-8', errors='replace')
    lowered = contents.lower()
    if pattern.search(contents) or coordinates.search(contents) or any(value in lowered for value in identity):
        failed.append(name)
if failed:
    print('Credentials or personal data detected (secret pattern, git identity, or coordinates); commit aborted:\n'
          + '\n'.join(failed), file=sys.stderr)
    sys.exit(1)

