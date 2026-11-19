#!/usr/bin/env bash
# Sets up the project: installs system libraries, creates .venv, installs requirements.
#
# Usage:
#   source setup.sh   # recommended: leaves the venv active in your terminal
#   ./setup.sh        # also works, but you'll need to activate the venv yourself afterwards

# This script needs bash. If started with `sh setup.sh` (dash on Debian/Ubuntu),
# re-run it under bash. Must stay POSIX-compatible up to this point.
if [ -z "${BASH_VERSION:-}" ]; then
    exec bash "$0" "$@"
fi

# Detect whether we're being sourced (so we `return` instead of `exit`,
# which would otherwise close the user's terminal).
(return 0 2>/dev/null) && _SOURCED=1 || _SOURCED=0

_setup_main() {
    local project_dir venv_dir python_bin
    project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    venv_dir="$project_dir/.venv"
    python_bin="${PYTHON:-python3}"

    if [[ "$(uname -s)" != "Linux" ]]; then
        echo "This script is for Linux only." >&2
        return 1
    fi

    if ! command -v "$python_bin" >/dev/null 2>&1; then
        echo "Error: $python_bin not found. Install Python 3 first." >&2
        return 1
    fi

    # ---- 1. System libraries (needed to build dbus-python) -----------------
    if command -v pkg-config >/dev/null 2>&1 \
        && pkg-config --exists dbus-1 glib-2.0 2>/dev/null \
        && "$python_bin" -c "import sysconfig, os, sys; sys.exit(not os.path.exists(os.path.join(sysconfig.get_paths()['include'], 'Python.h')))" 2>/dev/null; then
        echo "==> System libraries already installed, skipping."
    else
        local distro_ids=""
        if [[ -r /etc/os-release ]]; then
            # shellcheck disable=SC1091
            distro_ids="$(. /etc/os-release && echo "${ID:-} ${ID_LIKE:-}")"
        fi

        local -a install_cmd=()
        case " $distro_ids " in
            *" debian "*|*" ubuntu "*)
                install_cmd=(sh -c "apt-get update && apt-get install -y python3-venv python3-dev pkg-config build-essential libdbus-1-dev libglib2.0-dev") ;;
            *" fedora "*|*" rhel "*|*" centos "*)
                install_cmd=(dnf install -y python3-devel pkgconf-pkg-config gcc dbus-devel glib2-devel) ;;
            *" arch "*)
                install_cmd=(pacman -S --needed --noconfirm python pkgconf base-devel dbus glib2) ;;
            *" suse "*|*" opensuse "*)
                install_cmd=(zypper install -y python3-devel pkg-config gcc dbus-1-devel glib2-devel) ;;
            *)
                echo "Unrecognised distro ($distro_ids). Install these manually:" >&2
                echo "  pkg-config, a C compiler, Python dev headers, dbus dev headers, glib2 dev headers" >&2
                return 1 ;;
        esac

        echo "==> Installing system libraries (needs sudo): ${install_cmd[*]}"
        if [[ $EUID -eq 0 ]]; then
            "${install_cmd[@]}" || return 1
        else
            sudo "${install_cmd[@]}" || return 1
        fi
    fi

    # ---- 2. Virtual environment ---------------------------------------------
    if [[ -x "$venv_dir/bin/python" ]]; then
        echo "==> Using existing virtual environment at $venv_dir"
    else
        echo "==> Creating virtual environment at $venv_dir"
        "$python_bin" -m venv "$venv_dir" || return 1
    fi

    # shellcheck disable=SC1091
    source "$venv_dir/bin/activate" || return 1

    # ---- 3. Python packages -------------------------------------------------
    echo "==> Installing Python requirements"
    python -m pip install --upgrade pip || return 1
    python -m pip install -r "$project_dir/requirements.txt" || return 1

    echo
    echo "Setup complete."
    echo "The virtual environment is active. Run the app with:  python main.py"
}

# A script run as ./setup.sh is a child process, so it can't activate the venv
# in the terminal that launched it. Instead, open a new interactive shell with
# the venv already active. Typing `exit` leaves it.
_open_venv_shell() {
    local activate="$1"
    echo "(Opening a new shell with the venv active. Type 'exit' to leave it.)"
    if [[ "$(basename "${SHELL:-bash}")" == "bash" ]]; then
        # Load the user's normal ~/.bashrc, then activate the venv.
        exec bash --rcfile <(printf '[ -f ~/.bashrc ] && . ~/.bashrc\n. %q\n' "$activate") -i
    else
        # zsh/fish/etc.: set the same variables activate would, then start that shell.
        local venv_dir
        venv_dir="$(dirname "$(dirname "$activate")")"
        export VIRTUAL_ENV="$venv_dir"
        export PATH="$venv_dir/bin:$PATH"
        unset PYTHONHOME
        exec "$SHELL" -i
    fi
}

if [[ $_SOURCED -eq 1 ]]; then
    _setup_main
    _rc=$?
    unset -f _setup_main _open_venv_shell
    unset _SOURCED
    return $_rc
else
    _setup_main || exit $?
    # Only open a shell if a person is at the terminal (not in CI / piped runs).
    if [[ -t 0 && -t 1 ]]; then
        _open_venv_shell "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.venv/bin/activate"
    else
        echo "Activate the virtual environment with:  source .venv/bin/activate"
    fi
fi
