#!/usr/bin/env bash
# One-time (re-runnable) setup for this repo's optional machine integrations:
#
#   Step 0: report which of the project's CLI dependencies are installed
#   Step 1: systemd user services for quickshell + swayidle (systemd/*.service)
#   Step 2: greetd + cage, so greeter/ becomes the login screen
#
# Missing tools are reported in Step 0; Steps 1–2 just run their commands
# and rely on `set -e` to fail loudly if something required isn't there.

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
        "swayidle|Lockscreen idle timeout (this script's Step 1)"
        "systemctl|systemd user units (this script's Step 1)"
        "rsync|Greeter file deployment (this script's Step 2)"
        "greetd|Greeter login backend (this script's Step 2)"
        "cage|Greeter kiosk compositor (this script's Step 2)"
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

# --- Step 1: systemd user units for quickshell + swayidle ------------------

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

# --- Step 2: greeter (greetd + cage) ----------------------------------------

deploy_greeter_files() {
    sudo mkdir -p /etc/quickshell
    sudo rsync -a --delete --verbose "$REPO_ROOT/common" "$REPO_ROOT/greeter" /etc/quickshell/
    # Session launch needs the checkout's niri config path (greeter/ resolves
    # ../niri only when run from the repo; the /etc deploy can't see that).
    printf '%s\n' "$REPO_ROOT/niri/config.kdl" | sudo tee /etc/quickshell/greeter/niri-config.path >/dev/null
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
    install_systemd_units
    setup_greeter
}

main "$@"
