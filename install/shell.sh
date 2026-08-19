# Steps: symlink ~/.config/niri to this checkout's niri/, and install the
# systemd user units (quickshell + swayidle) that run the shell itself.
# Sourced by install.sh; run_shell is its entrypoint.
# Requires REPO_ROOT and CONFIG_HOME to already be set.

# niri resolves its config from ~/.config/niri/config.kdl for whatever user
# actually launches it — true whether that's this login shell, a TTY `niri`,
# or niri-session launched post-auth by the greeter. Symlinking there instead
# of overriding NIRI_CONFIG per launch path means every one of those paths
# picks up this checkout's config with zero extra plumbing, and each user on
# a shared machine gets their own independent symlink.
link_niri_config() {
    ensure_symlink "$CONFIG_HOME/niri" "$REPO_ROOT/niri" || true
}

install_systemd_units() {
    local shell_path="$REPO_ROOT/shell"
    local unit_dir="$CONFIG_HOME/systemd/user"
    local env_dir="$CONFIG_HOME/quickshell"
    local env_file="$env_dir/session.env"
    local units=(quickshell.service swayidle.service)
    local unit

    mkdir -p "$env_dir" "$unit_dir"
    # Specifiers like %E in the unit files resolve to XDG_CONFIG_HOME (or
    # ~/.config); keep this path in lockstep with EnvironmentFile=%E/quickshell/session.env.
    # XCURSOR_THEME/SIZE: quickshell.service doesn't inherit niri's own
    # environment{} block (see that unit's comment) or niri's built-in
    # XCURSOR env vars, so without these the lockscreen falls back to an
    # unthemed cursor while loading. Detected from the live GTK setting
    # rather than hardcoded, so this stays in sync if it's ever changed.
    {
        printf 'QS_CONFIG_PATH=%s\n' "$shell_path"
        printf 'XCURSOR_THEME=%s\n' "$(detect_cursor_theme)"
        printf 'XCURSOR_SIZE=%s\n' "$(detect_cursor_size)"
    } > "$env_file"
    echo "Wrote $env_file"

    for unit in "${units[@]}"; do
        ensure_symlink "$unit_dir/$unit" "$REPO_ROOT/systemd/$unit" force
    done

    systemctl --user daemon-reload
    systemctl --user enable "${units[@]}"
    systemctl --user add-wants niri.service "${units[@]}"
}

run_shell() {
    link_niri_config
    install_systemd_units
}
