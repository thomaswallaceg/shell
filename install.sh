#!/usr/bin/env bash
# One-time (re-runnable) setup for this repo's optional machine integrations:
#
#   Step 0: report which of the project's CLI dependencies are installed
#   Step 1: symlink ~/.config/niri -> this checkout's niri/ for the current user
#   Step 2: systemd user services for quickshell + swayidle (systemd/*.service)
#   Step 3: greetd + cage, so greeter/ becomes the login screen
#
# Missing tools are reported in Step 0; Steps 1–3 just run their commands
# and rely on `set -e` to fail loudly if something required isn't there.
#
# Step 1 is per-user by design: run this script as each user who should log
# into niri via this repo's config, so multiple accounts on the same machine
# (or sharing one greeter) each get their own ~/.config/niri symlink rather
# than depending on a single machine-wide config path.

# stop on the first failing command (-e)
# treat using an unset variable as an error (-u)
# make a pipeline fail if any command in it fails (-o pipefail)
# print each command, prefixed with "+", right before it runs (-x)
set -euxo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

warn() {
    echo "(!) $*" >&2
}

# --- Step 0: dependency check -----------------------------------------------

#
# Not listed (nothing to `command -v`): NetworkManager / UPower / PipeWire /
# BlueZ / MPRIS / PAM — those are consumed via Quickshell modules
# (`Quickshell.Networking`, `Services.UPower`, `Services.Pipewire`,
# `Bluetooth`, `Services.Mpris`, `Services.Pam`), not as CLI binaries.
# See README.md's dependency tables for the full stack list.
check_dependencies() {
    local deps=(
        "quickshell|Quickshell itself"
        "niri|niri compositor"
        "alacritty|Bar terminal-launching widgets (Niri.terminal)"
        "brightnessctl|Brightness widget + OSD"
        "sensors|CPU temperature (lm_sensors)"
        "top|CPU sampling (services/SystemInfo.qml)"
        "free|Memory sampling (services/SystemInfo.qml)"
        "gsettings|GTK/libadwaita light/dark preference (ThemeEngine)"
        "qt6ct|Qt6 app light/dark preference (ThemeEngine)"
        "btop|Bar CPU/temperature click-through"
        "wlctl|Bar network click-through"
        "bluetui|Bar bluetooth click-through"
        "wiremix|Bar volume click-through"
        "minical|Bar clock click-through"
        "xdg-open|Launcher file/directory opening"
        "fd|Launcher file search"
        "swayidle|Lockscreen idle timeout (this script's Step 2)"
        "systemctl|systemd user units (this script's Step 2) + power actions"
        "systemd-inhibit|Power menu reboot/shutdown inhibitor check"
        "rsync|Greeter file deployment (this script's Step 3)"
        "greetd|Greeter login backend (this script's Step 3)"
        "cage|Greeter kiosk compositor (this script's Step 3)"
    )

    local missing=()
    local entry cmd desc
    for entry in "${deps[@]}"; do
        cmd="${entry%%|*}"
        desc="${entry#*|}"
        if command -v "$cmd" >/dev/null 2>&1; then
            echo "[ok]      $cmd — $desc"
        else
            echo "[missing] $cmd — $desc"
            missing+=("$cmd")
        fi
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        warn "Missing: ${missing[*]}. Everything above is used by a specific widget/feature, not the whole shell."
    fi
}

# --- Step 1: symlink ~/.config/niri to this checkout's niri/ ---------------

# niri resolves its config from ~/.config/niri/config.kdl for whatever user
# actually launches it — true whether that's this login shell, a TTY `niri`,
# or niri-session launched post-auth by the greeter. Symlinking there instead
# of overriding NIRI_CONFIG per launch path means every one of those paths
# picks up this checkout's config with zero extra plumbing, and each user on
# a shared machine gets their own independent symlink.
link_niri_config() {
    local target="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
    local link_target="$REPO_ROOT/niri"

    if [ -L "$target" ]; then
        if [ "$(readlink -f "$target")" = "$(readlink -f "$link_target")" ]; then
            return
        fi
        warn "$target is a symlink pointing elsewhere; relinking to $link_target."
        rm "$target"
    elif [ -e "$target" ]; then
        warn "$target already exists and is not a symlink."
        local reply
        read -r -p "Back it up to $target.bak and replace with a symlink to $link_target? [y/N] " reply </dev/tty
        case "$reply" in
            y|Y|yes|YES)
                rm -rf "$target.bak"
                mv "$target" "$target.bak"
                ;;
            *)
                warn "Skipping niri config symlink."
                return
                ;;
        esac
    fi

    mkdir -p "$(dirname "$target")"
    ln -s "$link_target" "$target"
    echo "Linked $target -> $link_target"
}

# --- Step 2: systemd user units for quickshell + swayidle ------------------

install_systemd_units() {
    local shell_path="$REPO_ROOT/shell"
    local unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    local units=(quickshell.service swayidle.service)

    # move systemd units to the user's config directory, replace the @QUICKSHELL_SHELL_PATH@ placeholders with the actual path
    mkdir -p "$unit_dir"
    for unit in "${units[@]}"; do
        sed "s|@QUICKSHELL_SHELL_PATH@|$shell_path|g" "$REPO_ROOT/systemd/$unit" > "$unit_dir/$unit"
    done

    systemctl --user daemon-reload
    systemctl --user enable "${units[@]}"
    systemctl --user add-wants niri.service "${units[@]}"
}

# --- Step 3: greeter (greetd + cage) ----------------------------------------

deploy_greeter_files() {
    sudo mkdir -p /etc/quickshell
    sudo rsync -a --delete --verbose "$REPO_ROOT/common" "$REPO_ROOT/greeter" /etc/quickshell/
}

configure_greetd() {
    local src="$REPO_ROOT/greeter/config.toml"
    local dest=/etc/greetd/config.toml

    # An existing greetd config may have unrelated machine-specific settings —
    # ask before replacing it. Read from /dev/tty so this still works if the
    # script's stdin is redirected.
    if [ -f "$dest" ]; then
        warn "$dest already exists."
        local reply
        read -r -p "Overwrite with $src? [y/N] " reply </dev/tty
        case "$reply" in
            y|Y|yes|YES) ;;
            *)
                warn "Skipping greetd config install."
                return
                ;;
        esac
    fi

    sudo mkdir -p "$(dirname "$dest")"
    sudo cp --verbose "$src" "$dest"
}

enable_greetd() {
    sudo systemctl enable --now greetd
}

setup_greeter() {
    deploy_greeter_files
    configure_greetd
    enable_greetd
}

main() {
    check_dependencies
    link_niri_config
    install_systemd_units
    setup_greeter
}

main "$@"
