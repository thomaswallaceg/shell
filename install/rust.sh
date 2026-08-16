# Step: build+install this repo's callie submodule, and cargo-install the
# third-party wlctl/bluetui TUI helpers the bar shells out to.
# Sourced by install.sh; run_rust is its entrypoint.
# Requires REPO_ROOT to already be set.
#
# callie/ is a git submodule of this repo (github.com/thomaswallaceg/callie);
# this step does not add the submodule to .gitmodules (a one-time, manual
# `git submodule add` — see README.md) — it only makes sure an already-added
# submodule is checked out, then builds and installs it. wlctl and bluetui
# are unrelated third-party crates (crates.io), pinned to known-good versions
# below rather than tracked at latest, built unprivileged via
# `cargo install --root`, then installed to /usr/local/bin like callie so
# all three bar TUI helpers live in the same system-wide location.

# Bump these deliberately (check_cargo_tool_update warns, at run_rust time,
# if crates.io has moved past what's pinned here — it never bumps for you).
WLCTL_VERSION="0.1.9"
BLUETUI_VERSION="0.8.0"

sync_callie_submodule() {
    if [ ! -f "$REPO_ROOT/.gitmodules" ] || ! grep -q '^\[submodule "callie"\]' "$REPO_ROOT/.gitmodules" 2>/dev/null; then
        warn "callie/ is not registered as a submodule yet; see README.md's one-time 'git submodule add' step. Skipping callie build."
        return 1
    fi
    git -C "$REPO_ROOT" submodule update --init --recursive -- callie
}

build_callie() {
    local target_bin="$REPO_ROOT/callie/target/release/callie"

    ( cd "$REPO_ROOT/callie" && cargo build --release )

    sudo install -m 755 "$target_bin" /usr/local/bin/callie
    echo "Installed /usr/local/bin/callie"
}

# Non-fatal heads-up that a pinned crates.io version above is out of date —
# never bumps anything itself. Skips quietly if crates.io is unreachable.
check_cargo_tool_update() {
    local crate="$1"
    local pinned="$2"
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
        warn "$crate: pinned $pinned, crates.io has $latest available — bump ${crate^^}_VERSION in install/rust.sh if you want it."
    fi
}

# Third-party TUI helpers (crates.io), not part of this repo. Built
# unprivileged into a persistent cache dir (so re-runs get incremental
# rebuilds instead of recompiling from scratch), then the binaries are
# copied to /usr/local/bin — never run cargo itself under sudo. Drops any
# earlier plain `cargo install` copies from ~/.cargo/bin so there's exactly
# one copy of each on PATH.
install_cargo_tools() {
    local install_root="${XDG_CACHE_HOME:-$HOME/.cache}/shell-install/cargo-root"

    check_cargo_tool_update wlctl "$WLCTL_VERSION"
    check_cargo_tool_update bluetui "$BLUETUI_VERSION"

    cargo uninstall wlctl bluetui 2>/dev/null || true

    # --quiet: the binaries are copied out to /usr/local/bin below, so
    # cargo's "add $install_root/bin to your PATH" warning doesn't apply.
    cargo install --quiet --locked --root "$install_root" \
        "wlctl@$WLCTL_VERSION" "bluetui@$BLUETUI_VERSION"

    sudo install -m 755 "$install_root/bin/wlctl" "$install_root/bin/bluetui" /usr/local/bin/
    echo "Installed /usr/local/bin/wlctl and /usr/local/bin/bluetui"
}

run_rust() {
    if sync_callie_submodule; then
        build_callie
    fi
    install_cargo_tools
}
