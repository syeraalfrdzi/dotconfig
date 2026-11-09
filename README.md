# dotconfig

macOS configuration, synced through GitHub.

Some active configuration is linked to files in this repo with symlinks, so changes
show up directly in `git status`. The LazyVim, Herdr, skhd, and yabai backups are
added as copies; changes to the live files must be copied over again before
committing, until the user chooses to install symlinks. Nothing is uploaded
automatically in the background.

## Contents

| Folder | Configuration |
| --- | --- |
| `home/` | zsh, login profile, Powerlevel10k, Git |
| `config/nvim-lazyvim/` | Active Neovim: LazyVim, plugins, keymaps, LSP, formatters, lazy-lock |
| `config/zsh/` | zoxide, fzf, fzf-tab, and the `dotconfig` command |
| `config/gh/` | GitHub CLI preferences |
| `config/posting/` | Posting preferences |
| `config/spicetify/` | Spicetify marketplace theme colors (`config-xpui.ini` stays local, see below) |
| `apps/ghostty/` | Gruvbox Dark theme, transparency, titlebar, and Ghostty shortcuts for Herdr |
| `config/herdr/` | Herdr core/TUI preferences: shortcuts, theme, notifications, sounds |
| `config/herdr-app/` | Shortcuts and preferences for the Herdr desktop app |
| `config/skhd/` | Shortcuts for resizing/moving windows, desktops, and monitors, plus helper scripts |
| `config/yabai/` | yabai floating layout and mouse controls |
| `apps/vscode/` | Settings, keybindings, tasks, profiles, snippets, extension list |
| `config/opencode/` | OpenCode theme, session view, and MCP servers (Figma, Playwright) |
| `apps/claude-code/` | Claude Code status line script and media/ping watcher |
| `Brewfile` | Packages required by this configuration |
| `inventory/` | Homebrew packages, Codex preferences, and Herdr layout/theme references |

This repo does not include TickTick tokens, GitHub logins, Keychain, `.azure`,
`.gnupg`, terminal history, caches, logs, application databases, or any personal
application data. Neovim plugins are restored by lazy.nvim from `lazy-lock.json`;
zsh plugins are installed through Homebrew, so the plugin packages do not need to be
copied into the repo. Oh My Zsh exists on the original Mac but is not loaded by
`.zshrc`, so it is not a dependency. macOS system preferences and browser data are
not managed by this repo.

Personal data is kept out on purpose: shell files use `$HOME` instead of absolute home
paths, the git identity lives in an untracked `~/.gitconfig.local`, the status line
reads its weather coordinates from an untracked `~/.claude/statusline-location.json`,
and Spicetify's `config-xpui.ini` (whose `prefs_path` contains the macOS username)
stays local. The pre-commit check refuses a commit that contains this machine's git
name/email or decimal latitude/longitude values.

## Terminal and shell backup scope

The shell snapshot stores the active configuration as-is, without changing shortcuts,
aliases, or the prompt's appearance:

| Repo file | Manual restore location | Contents |
| --- | --- | --- |
| `home/.zshrc` | `~/.zshrc` | Tab autocomplete, autosuggestions, `ls` alias, PATH, plugin loading, and Bun completion |
| `home/.zprofile` | `~/.zprofile` | Homebrew environment and PATH at login |
| `home/.p10k.zsh` | `~/.p10k.zsh` | Powerlevel10k colors, icons, segments, clock, and transient prompt |
| `config/zsh/plugins.zsh` | `~/.config/zsh/plugins.zsh` | fzf/fzf-tab and zoxide integration, and the `dotconfig` function |

The backup also covers Ghostty, the active Neovim, Herdr, skhd, and yabai (see the
next section). Kitty, Apple Terminal, macOS shortcuts, `~/.zshenv`, and `~/.profile`
have not been added to this backup scope yet.

Not included: `~/.zshrc.local`, passwords, API keys/tokens, SSH private keys,
cookies/logins, command and conversation history, caches, and the contents of the user
folder as a whole. The history settings in `.zshrc` are saved; the contents of
`.zsh_history` are not. The credential pattern check helps filter files, but it does
not guarantee that every kind of secret is detected; review each new file before
committing.

### Shell-only restore (manual)

1. Clone this repo.
2. Install the shell dependencies: `fzf`, `fzf-tab`, `zoxide`, `powerlevel10k`,
   `zsh-autosuggestions`, and `lsd` through Homebrew; pick a Nerd Font in the terminal
   so the prompt icons display. Install Bun and OpenCode separately if needed.
3. Save a copy of any existing target files in a backup folder outside the repo.
   If a target is a symlink, also save the contents of what it points to and check it
   before overwriting.
4. Copy only the four files in the table to their destinations; create
   `~/.config/zsh/` if it does not exist. Do not run `bootstrap.sh` or `install.sh` if
   you only want to restore the shell, because those scripts also manage other
   applications.
5. `.zshrc` and `.zprofile` use `$HOME`, so no path edits are needed for a Mac account
   with a different name. Put your git identity in `~/.gitconfig.local` (see below).
6. Open a new Zsh session. App logins, binaries, and history data must be restored or
   installed separately.

## Ghostty, Neovim, Herdr, skhd, and yabai backup

| Source in repo | Manual restore destination |
| --- | --- |
| `apps/ghostty/config.ghostty` | `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` |
| `config/nvim-lazyvim/` | `~/.config/nvim/` |
| `config/herdr/config.toml` | `~/.config/herdr/config.toml` |
| `config/herdr-app/keys.json` | `~/.config/herdr-app/keys.json` |
| `config/herdr-app/settings.json` | `~/.config/herdr-app/settings.json` |
| `config/skhd/` | `~/.config/skhd/` |
| `config/yabai/` | `~/.config/yabai/` |

Before restoring, close the related apps and save a backup of the target files/folders
outside the repo. Copy only the sources listed in the table. For Neovim, keep the old
configuration folder intact and restore into an empty `nvim` folder; do not mix files
from other Neovim configurations. Plugins, caches, undo, shada, and personal Org notes
are not copied; `lazy-lock.json` stores the plugin versions. The `guide.md` file is a
configuration guide, not the contents of a notes directory. Install plugin
dependencies as needed, and adjust the notes/project directory paths if you move to a
different account or Mac.

Install Ghostty, Neovim, the Herdr app/core, skhd, yabai, and `jq` separately.
The skhd/yabai configuration uses `/opt/homebrew/bin/yabai` (Apple Silicon); adjust it
if your Homebrew lives elsewhere. Keep the executable permission on `yabairc`.
Grant skhd/yabai Accessibility permission manually through macOS; permissions and
service status are not part of the backup. The backup makes no changes to SIP,
permissions, or services.

Herdr stores only preferences and shortcuts. Not included: `session.json`,
`session-snapshots/`, running terminals/agents, the active workspace/tab,
`shared.json`, `view.json`, `data/`, telemetry, logs, sockets, and credentials.
`inventory/herdr-app/layouts/` (including `.state/`) and `themes/` are reference
snapshots of the appearance, not files that are installed automatically. Do not
overwrite Herdr's built-in layouts/mods or edit `.state/` directly; use the layout
clone feature and the app settings to adjust the appearance on the target Herdr
version. Built-in mods, frames, icons, and type definitions are restored by installing
Herdr, not from this backup. The backup process does not edit any active mod/layout.

## OpenCode and Claude Code status line backup

Both are copied as-is and restored manually (not yet installed by `install.sh`):

| Repo file | Manual restore location |
| --- | --- |
| `config/opencode/{opencode,cli}.json`, `tui.jsonc` | `~/.config/opencode/` |
| `apps/claude-code/statusline*` | `~/.claude/` |

OpenCode: `service.json` (which holds the service password) is deliberately left out
and git-ignored. The Herdr-generated integration files (`herdr-tui-session.js`,
`herdr-opencode/`, `plugins/herdr-agent-state.js`) are not copied either; reinstall the
integration from Herdr, because `cli.json` and `tui.jsonc` refer to those files.

The Claude Code status line needs Bun, `nowplaying-cli` (in `/opt/homebrew/bin`), and
the following entry in `~/.claude/settings.json` (replace `YOUR_USER` with the macOS
account name; `settings.json` does not expand `$HOME`):

```json
"statusLine": {
  "type": "command",
  "command": "/Users/YOUR_USER/.bun/bin/bun /Users/YOUR_USER/.claude/statusline.ts",
  "refreshInterval": 1
}
```

The weather column is optional: it needs `~/.claude/statusline-location.json` containing
`{"latitude": 0.0, "longitude": 0.0}` with your own coordinates (git-ignored); without
the file the column stays empty. The iCloud calendar is likewise optional through
`~/.claude/statusline-icloud.json` (credentials, git-ignored, never added to the repo).

## Activate on this Mac

```zsh
cd ~/.config/dotconfig
zsh install.sh --dry-run  # list the symlinks
zsh install.sh
exec zsh
```

Every file/folder that gets replaced is saved in `.backups/<time>/` along with a
manifest. Backups are not committed to Git. Extra local settings can be kept in
`~/.zshrc.local`. The installer picks `config/nvim-lazyvim/` for Neovim. Herdr, skhd,
and yabai are still restored manually according to the table; the installer does not
replace Herdr's runtime folder.

## Sync

```zsh
dotconfig status
dotconfig push "Update nvim and zsh configuration"
dotconfig pull
```

Before the repo's `.zshrc` is activated, run `zsh ~/.config/dotconfig/sync.sh push`.
`push` saves the changes, pulls updates with a rebase, and then sends them to GitHub.
`pull` requires a clean working tree and only fast-forwards.
If a conflict occurs, the script stops so it can be resolved manually.
The pre-commit hook checks for common credential patterns and for this machine's git
name/email and decimal coordinates; still review `git diff --cached` when adding
configuration for a new application. `sync.sh` records commit times in UTC so the
history does not reveal a timezone.

## Other Macs

Install Homebrew and the GitHub CLI, log in to GitHub, then:

```zsh
gh repo clone <your-github-username>/dotconfig ~/.config/dotconfig
cd ~/.config/dotconfig
zsh bootstrap.sh
exec zsh
```

Open `nvim` to restore the plugins. The GitHub CLI and other apps need to be logged in
again. `inventory/homebrew-*.txt` lists the packages on the source Mac; it is not an
automatic installation of every app and service. `inventory/codex-preferences.toml` is
a reference; the Codex runtime integration is still managed by the app.

If VS Code is available, restore the extensions with:

```zsh
while IFS= read -r extension; do
  code --install-extension "$extension"
done < apps/vscode/extensions.txt
```

Spicetify Marketplace is an add-on app package, not configuration; reinstall it by
following the official instructions at https://github.com/spicetify/marketplace before
using the theme. Spicetify's own `config-xpui.ini` is not in this repo (its `prefs_path`
is an absolute path containing the macOS username); run `spicetify` once to generate it.
`home/.gitconfig` includes `~/.gitconfig.local`; create that file with your identity:

```ini
[user]
	name = Your Name
	email = you@example.com
```

## Restore a previous configuration

```zsh
python3 scripts/restore.py .backups/BACKUP-FOLDER-NAME
```

Restoring only replaces symlinks that still point into this repo. Files that have been
replaced manually are skipped.
