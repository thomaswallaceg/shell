# Step: build+install this repo's callie submodule, and cargo-install the
# third-party wlctl/bluetui TUI helpers the bar shells out to, plus handlr
# (crate handlr-regex), the launcher's file opener, fd (crate fd-find), its
# file search, and fend, its calculator.
# Sourced by install.sh; run_rust is its entrypoint.
# Requires REPO_ROOT to already be set.

# Bump these deliberately (check_cargo_tool_update warns, at run_rust time,
# if crates.io has moved past what's pinned here — it never bumps for you).
WLCTL_VERSION="0.1.9"
BLUETUI_VERSION="0.8.0"
HANDLR_VERSION="0.13.0"
FEND_VERSION="1.5.8"
FD_VERSION="10.5.0"

sync_callie_submodule() {
    if [ ! -f "$REPO_ROOT/.gitmodules" ] || ! grep -q '^\[submodule "callie"\]' "$REPO_ROOT/.gitmodules" 2>/dev/null; then
        warn "callie/ is not registered as a submodule yet; see README.md's one-time 'git submodule add' step. Skipping callie build."
        return 1
    fi
    run git -C "$REPO_ROOT" submodule update --quiet --init --recursive -- callie
}

build_callie() {
    local target_bin="$REPO_ROOT/callie/target/release/callie"

    # Not --quiet: a first build takes a while, and the progress shows it's moving.
    run cargo build --release --manifest-path "$REPO_ROOT/callie/Cargo.toml"

    run sudo install -m 755 "$target_bin" /usr/local/bin/callie
}

# Non-fatal heads-up that a pinned crates.io version above is out of date —
# never bumps anything itself. Skips quietly if crates.io is unreachable.
check_cargo_tool_update() {
    local crate="$1"
    local pinned="$2"
    local pin_var="${3:-${crate^^}_VERSION}"
    local latest

    if ! command -v curl >/dev/null 2>&1; then
        return 0
    fi

    # `|| true`: this check must never trip the top-level `set -e` — a
    # network hiccup or 403 here shouldn't abort the whole install.sh run.
    latest="$(curl -fsSL -A "shell-install-script (github.com/thomaswallaceg/shell)" \
        "https://crates.io/api/v1/crates/$crate" 2>/dev/null \
        | grep -o '"max_stable_version":"[^"]*"' | cut -d'"' -f4)" || true

    if [ -z "$latest" ]; then
        warn "Could not check crates.io for $crate's latest version (offline?) — skipping."
        return 0
    fi

    if [ "$latest" != "$pinned" ]; then
        warn "$crate: pinned $pinned, crates.io has $latest available — bump $pin_var in install/rust.sh if you want it."
    fi
}

# Built unprivileged into a persistent cache dir, then copied to /usr/local/bin.
install_cargo_tools() {
    local install_root="${XDG_CACHE_HOME:-$HOME/.cache}/shell-install/cargo-root"

    check_cargo_tool_update wlctl "$WLCTL_VERSION"
    check_cargo_tool_update bluetui "$BLUETUI_VERSION"
    # Crate is handlr-regex, binary is handlr.
    check_cargo_tool_update handlr-regex "$HANDLR_VERSION" HANDLR_VERSION
    check_cargo_tool_update fend "$FEND_VERSION"
    # Crate is fd-find, binary is fd. From crates.io rather than the distro
    # because Debian/Ubuntu package it as `fdfind`.
    check_cargo_tool_update fd-find "$FD_VERSION" FD_VERSION

    cargo uninstall wlctl bluetui handlr-regex fend fd-find 2>/dev/null || true

    # --quiet: the binaries are copied out to /usr/local/bin below, so
    # cargo's "add $install_root/bin to your PATH" warning doesn't apply.
    run cargo install --quiet --locked --root "$install_root" \
        "wlctl@$WLCTL_VERSION" "bluetui@$BLUETUI_VERSION" "handlr-regex@$HANDLR_VERSION" \
        "fend@$FEND_VERSION" "fd-find@$FD_VERSION"

    run sudo install -m 755 "$install_root/bin/wlctl" "$install_root/bin/bluetui" "$install_root/bin/handlr" "$install_root/bin/fend" "$install_root/bin/fd" /usr/local/bin/
}

run_rust() {
    if sync_callie_submodule; then
        build_callie
    fi
    install_cargo_tools
}
