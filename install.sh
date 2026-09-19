#!/usr/bin/env bash
# One-time (re-runnable) setup for this repo's optional machine integrations.
# Split into parts under install/, dispatched by the subcommand below:
#
#   utils    report which of the project's CLI dependencies are installed
#   shell    symlink ~/.config/niri -> this checkout's niri/, and install the
#            systemd user units (quickshell + swayidle) for the current user
#   greeter  greetd + cage, so greeter/ becomes the login screen (installs
#            greeter/ via `make install-greeter` under $PREFIX, default /usr/local)
#   rust     build+install the callie submodule, and cargo-install wlctl/bluetui
#   all      run all of the above, in the order listed (default)
#
# `utils` also runs first before `shell`, `greeter` and `rust`
#
# stop on the first failing command (-e)
# treat using an unset variable as an error (-u)
# make a pipeline fail if any command in it fails (-o pipefail)
# print each command, prefixed with "+", right before it runs (-x)
set -euxo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
# Install prefix for the parts that go through the Makefile (same default).
PREFIX="${PREFIX:-/usr/local}"
INSTALL_DIR="$REPO_ROOT/install"

# shellcheck source=install/lib.sh
source "$INSTALL_DIR/lib.sh"
# shellcheck source=install/utils.sh
source "$INSTALL_DIR/utils.sh"
# shellcheck source=install/shell.sh
source "$INSTALL_DIR/shell.sh"
# shellcheck source=install/greeter.sh
source "$INSTALL_DIR/greeter.sh"
# shellcheck source=install/rust.sh
source "$INSTALL_DIR/rust.sh"

if [ "$EUID" -eq 0 ]; then
    warn "Don't run this as root (or via sudo); run it as the user who logs into niri."
    exit 1
fi

usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [utils|shell|greeter|rust|all]

  utils    report which CLI dependencies are installed (also runs
           first before every other target)
  shell    symlink niri config + install systemd units (per-user)
  greeter  install greetd + cage as the login screen
           (greeter files via make, under PREFIX=$PREFIX)
  rust     build callie (submodule) + cargo-install wlctl/bluetui
  all      run all of the above (default)
EOF
}

FAILED_STEPS=()

# Run one step (run_<name>) in a subshell, so its first failing command ends
# only that step. errexit is switched off around the subshell instead of
# writing `( ... ) || ...`: bash ignores -e inside anything whose exit status
# is being tested, so the step would otherwise carry on past its errors.
run_step() {
    local name="$1"
    local status

    set +e
    ( set -e; "run_$name" )
    status=$?
    set -e

    if [ "$status" -ne 0 ]; then
        warn "Step '$name' failed (exit $status); continuing with the remaining steps."
        FAILED_STEPS+=("$name")
    fi
}

main() {
    local target="${1:-all}"
    local steps step

    case "$target" in
        utils)
            steps=(utils)
            ;;
        shell|greeter|rust)
            steps=(utils "$target")
            ;;
        all)
            steps=(utils shell greeter rust)
            ;;
        -h|--help)
            usage
            return 0
            ;;
        *)
            warn "Unknown target: $target"
            usage
            exit 1
            ;;
    esac

    for step in "${steps[@]}"; do
        run_step "$step"
    done

    if [ "${#FAILED_STEPS[@]}" -gt 0 ]; then
        warn "Failed steps: ${FAILED_STEPS[*]}. See each step's error above."
        exit 1
    fi
}

main "$@"
