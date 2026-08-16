# Step: greetd + cage, so greeter/ becomes the login screen.
# Sourced by install.sh; run_greeter is its entrypoint.
# Requires REPO_ROOT to already be set.

deploy_greeter_files() {
    # Still a copy: the greeter system user usually can't read $HOME, and the
    # greeter runs before login (encrypted homes aren't unlocked yet).
    sudo mkdir -p /etc/quickshell
    sudo rsync -a --delete --verbose "$REPO_ROOT/common" "$REPO_ROOT/greeter" /etc/quickshell/
}

configure_greetd() {
    local src="$REPO_ROOT/greeter/config.toml"
    local dest=/etc/greetd/config.toml

    # greetd reads this as root, so a symlink into the checkout is fine — unlike
    # /etc/quickshell, which must stay a real copy the greeter user can read.
    sudo mkdir -p "$(dirname "$dest")"

    if [ -L "$dest" ]; then
        if [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
            return 0
        fi
        warn "$dest is a symlink pointing elsewhere; relinking to $src."
        sudo rm "$dest"
    elif [ -e "$dest" ]; then
        warn "$dest already exists and is not a symlink."
        local reply
        read -r -p "Back it up to $dest.bak and replace with a symlink to $src? [y/N] " reply </dev/tty
        case "$reply" in
            y|Y|yes|YES)
                sudo rm -rf "$dest.bak"
                sudo mv "$dest" "$dest.bak"
                ;;
            *)
                warn "Skipping greetd config symlink."
                return 0
                ;;
        esac
    fi

    sudo ln -s "$src" "$dest"
    echo "Linked $dest -> $src"
}

enable_greetd() {
    sudo systemctl enable --now greetd
}

run_greeter() {
    deploy_greeter_files
    configure_greetd
    enable_greetd
}
