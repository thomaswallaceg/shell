# Step: report which of the project's CLI dependencies are installed.
# Sourced by install.sh; run_utils is its entrypoint.
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
        "upower|Battery charge-limit discovery (BatteryWidget)"
        "busctl|Battery charge-limit toggle via UPower D-Bus"
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
        "xdg-open|Launcher file/directory opening"
        "fd|Launcher file search"
        "zenity|Wallpaper file picker (launcher / qs ipc wallpaper pick)"
        "swayidle|Lockscreen idle timeout (this script's shell step)"
        "systemctl|systemd user units (this script's shell step) + power actions"
        "systemd-inhibit|Power menu reboot/shutdown inhibitor check"
        "rsync|Greeter file deployment (this script's greeter step)"
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
}

run_utils() {
    check_dependencies
}
