# Step: install the shell and its systemd user units (quickshell + swayidle)
# system-wide via `make install-shell install-units`. The niri config's shell
# include starts them. The session runs the installed shell, not this checkout:
# to develop, stop thomas-shell.service and run `qs -p ./shell` by hand.
# The niri config is its own repo, cloned to ~/.config/niri; nothing here
# touches it.
# Sourced by install.sh; run_shell is its entrypoint.
# Requires REPO_ROOT and PREFIX to already be set.

install_shell_and_units() {
    sudo make -C "$REPO_ROOT" PREFIX="$PREFIX" install-shell install-units

    # daemon-reload also re-reads environment.d, so units started from now on
    # get the installed QS_CONFIG_PATH.
    systemctl --user daemon-reload

    # No `enable`: the niri config's shell include starts thomas-shell.service
    # (which pulls in swayidle), so swapping shells needs no systemctl.
    warn "Log out and back in to switch the running session to the installed shell."
}

run_shell() {
    install_shell_and_units
}
