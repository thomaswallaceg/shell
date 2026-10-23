# Shared helpers sourced by install/*.sh. Not meant to be run directly.

warn() {
    echo "(!) $*" >&2
}

# Print a command, then run it. For the steps' actual changes (sudo, make,
# cargo, systemctl), so they stay visible without VERBOSE=1's full trace.
run() {
    echo "+ $*"
    "$@"
}
