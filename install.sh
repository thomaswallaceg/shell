#!/usr/bin/env bash
# One-time (re-runnable) setup for this repo's optional machine integrations:
#
#   Step 0: report which of the project's CLI dependencies are installed
#   Step 1: symlink ~/.config/niri -> this checkout's niri/ for the current user
#   Step 2: symlink systemd user units + write QS_CONFIG_PATH env file
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
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

warn() {
    echo "(!) $*" >&2
}

# Make LINK_PATH a symlink to TARGET_PATH.
# With a third argument of "force", replace a pre-existing non-symlink without
# asking (used for files this script exclusively manages). Otherwise prompt
# before backing up and replacing a real file/directory.
ensure_symlink() {
    local link_path="$1"
    local target_path="$2"
    local mode="${3:-ask}"

    mkdir -p "$(dirname "$link_path")"

    if [ -L "$link_path" ]; then
        if [ "$(readlink -f "$link_path")" = "$(readlink -f "$target_path")" ]; then
            return 0
        fi
        warn "$link_path is a symlink pointing elsewhere; relinking to $target_path."
        rm "$link_path"
    elif [ -e "$link_path" ]; then
        if [ "$mode" = "force" ]; then
            warn "Replacing $link_path with a symlink to $target_path."
            rm -f "$link_path"
        else
            warn "$link_path already exists and is not a symlink."
            local reply
            read -r -p "Back it up to $link_path.bak and replace with a symlink to $target_path? [y/N] " reply </dev/tty
            case "$reply" in
                y|Y|yes|YES)
                    rm -rf "$link_path.bak"
                    mv "$link_path" "$link_path.bak"
                    ;;
                *)
                    warn "Skipping symlink for $link_path."
                    return 1
                    ;;
            esac
        fi
    fi

    ln -s "$target_path" "$link_path"
    echo "Linked $link_path -> $target_path"
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
    ensure_symlink "$CONFIG_HOME/niri" "$REPO_ROOT/niri" || true
}

# --- Step 2: systemd user units for quickshell + swayidle ------------------

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
    printf 'QS_CONFIG_PATH=%s\n' "$shell_path" > "$env_file"
    echo "Wrote $env_file"

    for unit in "${units[@]}"; do
        ensure_symlink "$unit_dir/$unit" "$REPO_ROOT/systemd/$unit" force
    done

    systemctl --user daemon-reload
    systemctl --user enable "${units[@]}"
    systemctl --user add-wants niri.service "${units[@]}"
}

# --- Step 3: greeter (greetd + cage) ----------------------------------------

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
