#!/bin/bash
set -euo pipefail
export CLAUDE_STATUSLINE_TMP="$("$HOME/.bun/bin/bun" -e 'process.stdout.write(require("os").tmpdir())')"
exec /usr/bin/lockf -t 0 "$CLAUDE_STATUSLINE_TMP/claude-statusline-media.lock" "$HOME/.bun/bin/bun" "$HOME/.claude/statusline-media.ts"
