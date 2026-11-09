#!/bin/sh

# Keep the same window focused after sending it to another desktop or monitor.
case "$1:$2" in
    space:prev|space:next|display:prev|display:next) ;;
    *) exit 1 ;;
esac

window_id=$(/opt/homebrew/bin/yabai -m query --windows id --window | /usr/bin/jq -er '.id') || exit 1
/opt/homebrew/bin/yabai -m window "$window_id" "--$1" "$2" || exit 1
exec /opt/homebrew/bin/yabai -m window --focus "$window_id"
