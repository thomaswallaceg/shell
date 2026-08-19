# Shared helpers sourced by install/*.sh. Not meant to be run directly.

warn() {
    echo "(!) $*" >&2
}

# Read the cursor theme/size the user actually has configured (GTK's
# org.gnome.desktop.interface, same source ThemeEngine already reads for
# light/dark). Used to fill in XCURSOR_THEME/XCURSOR_SIZE for processes that
# don't get niri's own env vars for free (systemd user units, the greeter's
# separate cage session) without pinning this repo to any specific theme.
# Falls back to niri's own defaults ("default", 24) if gsettings has nothing.
detect_cursor_theme() {
    local theme
    theme=$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | sed "s/^'//; s/'$//")
    [ -n "$theme" ] || theme="default"
    echo "$theme"
}

detect_cursor_size() {
    local size
    size=$(gsettings get org.gnome.desktop.interface cursor-size 2>/dev/null)
    case "$size" in
        ''|*[!0-9]*) size=24 ;;
    esac
    echo "$size"
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
