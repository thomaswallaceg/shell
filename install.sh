#!/usr/bin/env bash
# One-time (re-runnable) setup for this repo's optional machine integrations.
# Split into parts under install/, dispatched by the subcommand below:
#
#   utils    report which of the project's CLI dependencies are installed
#   shell    symlink ~/.config/niri -> this checkout's niri/, and install the
#            systemd user units (quickshell + swayidle) for the current user
#   greeter  greetd + cage, so greeter/ becomes the login screen
#   rust     build+install the callie submodule, and cargo-install wlctl/bluetui
#   all      run all of the above, in the order listed (default)
#
# `shell` is per-user by design: run it as each user who should log into
# niri via this repo's config, so multiple accounts on the same machine
# (or sharing one greeter) each get their own ~/.config/niri symlink rather
# than depending on a single machine-wide config path.
#
# Missing tools are reported by `utils`; `shell` and `greeter` just run their
# commands and rely on `set -e` to fail loudly if something required isn't there.

# stop on the first failing command (-e)
# treat using an unset variable as an error (-u)
# make a pipeline fail if any command in it fails (-o pipefail)
# print each command, prefixed with "+", right before it runs (-x)
set -euxo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
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

usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [utils|shell|greeter|rust|all]

  utils    report which CLI dependencies are installed
  shell    symlink niri config + install systemd units (per-user)
  greeter  install greetd + cage as the login screen
  rust     build callie (submodule) + cargo-install wlctl/bluetui
  all      run all of the above (default)
EOF
}

main() {
    local target="${1:-all}"

    case "$target" in
        utils)
            run_utils
            ;;
        shell)
            run_shell
            ;;
        greeter)
            run_greeter
            ;;
        rust)
            run_rust
            ;;
        all)
            run_utils
            run_shell
            run_greeter
            run_rust
            ;;
        -h|--help)
            usage
            ;;
        *)
            warn "Unknown target: $target"
            usage
            exit 1
            ;;
    esac
}

main "$@"
