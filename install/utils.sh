# Step: report which of the project's CLI dependencies are installed.
# Not listed (nothing to `command -v`): NetworkManager / UPower / PipeWire /
# BlueZ / MPRIS / PAM — those are consumed via Quickshell modules
# (`Quickshell.Networking`, `Services.UPower`, `Services.Pipewire`,
# `Bluetooth`, `Services.Mpris`, `Services.Pam`), not as CLI binaries.

check_dependencies() {
    local deps=(
        "quickshell|Quickshell itself"
        "niri|niri compositor"
        "alacritty|Bar terminal-launching widgets (Niri.terminal)"
        "brightnessctl|Brightness widget + OSD"
        "upower|Battery charge-limit discovery (BatteryWidget)"
        "busctl|Battery charge-limit toggle via UPower D-Bus"
        "gdbus|Lock before sleep (services/SleepWatcher.qml)"
        "systemd-inhibit|Lock before sleep + power menu inhibitor check"
        "sensors|CPU temperature (lm_sensors)"
        "free|Memory sampling (services/SystemInfo.qml)"
        "gsettings|GTK/libadwaita light/dark preference (ThemeEngine)"
        "qt6ct|Qt6 app light/dark preference (ThemeEngine)"
        "btop|Bar CPU/temperature click-through"
        "wlctl|Bar network click-through"
        "bluetui|Bar bluetooth click-through"
        "wiremix|Bar volume click-through"
        "callie|Bar clock click-through"
        "cargo|Rust toolchain (this script's rust step: cargo build/install)"
        "curl|crates.io version-pin check (this script's rust step, non-fatal if missing)"
        "xdg-open|Launcher file/directory opening"
        "fd|Launcher file search"
        "qalc|Launcher calculator (Calculator.qml, libqalculate)"
        "zenity|Wallpaper file picker (launcher / qs ipc wallpaper pick)"
        "pkexec|Launcher's \"Sync theme to greeter\" action"
        "jq|Launcher's \"Sync theme to greeter\" action (sync-greeter-preferences.sh)"
        "systemctl|systemd user units (this script's shell step) + power actions"
        "make|Installing the units + greeter files (this script's shell and greeter steps)"
        "greetd|Greeter login backend (this script's greeter step)"
        "cage|Greeter kiosk compositor (this script's greeter step)"
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

    check_cursor_theme
}

check_cursor_theme() {
    local dir
    for dir in "$HOME/.local/share/icons" "$HOME/.icons" /usr/share/icons /usr/local/share/icons; do
        if [ -d "$dir/Adwaita/cursors" ]; then
            echo "[ok]      Adwaita cursor theme — cursor for niri, the shell and the greeter ($dir/Adwaita)"
            return 0
        fi
    done
    echo "[missing] Adwaita cursor theme — cursor for niri, the shell and the greeter"
    warn "Adwaita cursor theme not found; install your distro's adwaita-cursors or adwaita-icon-theme package."
}

run_utils() {
    check_dependencies
}
