#!/bin/sh
# Writes theme/fontFamily into the deployed greeter's own preferences.json
# (see common/state/Preferences.qml). The greeter is a separate Quickshell
# config root running as its own system user, so it never shares the main
# shell's saved preferences on its own — this is what LauncherTab.qml's
# "Sync theme to greeter" action runs (via pkexec, since it's root/greeter
# owned) to copy the current selection over one-shot.
#
# The greeter's Quickshell.statePath() hash is MD5(absolute path to its
# shell.qml) — deterministic, since /etc/quickshell/greeter is a real
# directory (not a symlink), deployed as-is by
# install/greeter.sh's deploy_greeter_files. So this doesn't need to ask a
# running greeter process for its own path; it computes the same hash
# Quickshell itself would.
set -eu

theme="$1"
font_family="$2"

greeter_config_path="/etc/quickshell/greeter/shell.qml"
hash="$(printf '%s' "$greeter_config_path" | md5sum | cut -d' ' -f1)"

greeter_home="$(getent passwd greeter | cut -d: -f6)"
state_dir="$greeter_home/.local/state/quickshell/by-shell/$hash"
prefs_file="$state_dir/preferences.json"

mkdir -p "$state_dir"
[ -f "$prefs_file" ] || echo '{}' > "$prefs_file"

tmp="$(mktemp "$state_dir/preferences.json.XXXXXX")"
jq --arg theme "$theme" --arg font "$font_family" \
    '.theme = $theme | .fontFamily = $font' \
    "$prefs_file" > "$tmp"
mv "$tmp" "$prefs_file"

# The greeter runs as its own unprivileged system user, not root — it needs
# to be able to read (and later overwrite, e.g. FileView's own write-back)
# this file and its directory itself.
chown -R greeter:greeter "$state_dir"
