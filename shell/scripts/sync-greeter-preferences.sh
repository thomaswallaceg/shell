#!/bin/sh
# Copies a theme and font to the login screen by writing the admin-owned
# /etc/thomas-shell/greeter.json, which the greeter reads (read-only).
# Runs as root through pkexec (polkit action
# io.github.thomaswallaceg.thomas-shell.sync-greeter).

set -eu

theme="$1"
font_family="$2"

themes_file="$(dirname "$(readlink -f "$0")")/../common/theme/themes.json"
if ! jq -e --arg id "$theme" 'any(.[]; .id == $id)' "$themes_file" > /dev/null; then
    echo "Unknown theme: $theme" >&2
    exit 1
fi
case "$font_family" in
    *[[:cntrl:]]*)
        echo "Invalid font name" >&2
        exit 1
        ;;
esac

prefs_dir=/etc/thomas-shell
prefs_file="$prefs_dir/greeter.json"
mkdir -p "$prefs_dir"

tmp="$(mktemp "$prefs_dir/greeter.json.XXXXXX")"
{ cat "$prefs_file" 2>/dev/null || echo '{}'; } \
    | jq --arg theme "$theme" --arg font "$font_family" \
        '.theme = $theme | .fontFamily = $font' > "$tmp"
chmod 644 "$tmp"
mv "$tmp" "$prefs_file"
