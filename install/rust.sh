# Step: build+install this repo's callie submodule, and cargo-install the
# third-party wlctl/bluetui TUI helpers the bar shells out to.
# Sourced by install.sh; run_rust is its entrypoint.
# Requires REPO_ROOT to already be set.
#
# callie/ is a git submodule of this repo (github.com/thomaswallaceg/callie);
# this step does not add the submodule to .gitmodules (a one-time, manual
# `git submodule add` — see README.md) — it only makes sure an already-added
# submodule is checked out, then builds and installs it. wlctl and bluetui
# are unrelated third-party crates (crates.io), built unprivileged via
# `cargo install --root`, then installed to /usr/local/bin like callie so
# all three bar TUI helpers live in the same system-wide location.

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

# Third-party TUI helpers (crates.io), not part of this repo. Built
# unprivileged into a persistent cache dir (so re-runs get incremental
# rebuilds instead of recompiling from scratch), then the binaries are
# copied to /usr/local/bin — never run cargo itself under sudo. Drops any
# earlier plain `cargo install` copies from ~/.cargo/bin so there's exactly
# one copy of each on PATH.
install_cargo_tools() {
    local install_root="${XDG_CACHE_HOME:-$HOME/.cache}/shell-install/cargo-root"

    cargo uninstall wlctl bluetui 2>/dev/null || true

    # --quiet: the binaries are copied out to /usr/local/bin below, so
    # cargo's "add $install_root/bin to your PATH" warning doesn't apply.
    cargo install --quiet --locked --root "$install_root" wlctl bluetui

    sudo install -m 755 "$install_root/bin/wlctl" "$install_root/bin/bluetui" /usr/local/bin/
    echo "Installed /usr/local/bin/wlctl and /usr/local/bin/bluetui"
}

run_rust() {
    if sync_callie_submodule; then
        build_callie
    fi
    install_cargo_tools
}
