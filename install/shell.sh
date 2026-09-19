# Steps: symlink ~/.config/niri to this checkout's niri/, install the shell and
# its systemd user units (quickshell + swayidle) system-wide via
# `make install-shell install-units`, and enable the units for the current
# user. The session runs the installed shell, not this checkout: to develop,
# stop thomas-shell.service and run `qs -p ./shell` by hand.
# Sourced by install.sh; run_shell is its entrypoint.
# Requires REPO_ROOT, CONFIG_HOME and PREFIX to already be set.

# Per-user: niri reads ~/.config/niri/config.kdl for whoever launches it.
link_niri_config() {
    ensure_symlink "$CONFIG_HOME/niri" "$REPO_ROOT/niri" || true
}

UNITS=(thomas-shell.service thomas-shell-swayidle.service)

install_shell_and_units() {
    sudo make -C "$REPO_ROOT" PREFIX="$PREFIX" install-shell install-units

    # daemon-reload also re-reads environment.d, so units started from now on
    # get the installed QS_CONFIG_PATH.
    systemctl --user daemon-reload
    systemctl --user enable "${UNITS[@]}"
    systemctl --user add-wants niri.service "${UNITS[@]}"

    warn "Log out and back in to switch the running session to the installed shell."
}

run_shell() {
    link_niri_config
    install_shell_and_units
}
