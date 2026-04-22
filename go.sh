#!/usr/bin/env bash
set -Eeuo pipefail

PYTHON_BIN="python3"
VENV_DIR="venv"
GETPIP_URL="https://bootstrap.pypa.io/get-pip.py"

log_info()    { printf "\033[1;34m[INFO]\033[0m %s\n" "$1"; }
log_success() { printf "\033[1;32m[SUCCESS]\033[0m %s\n" "$1"; }
log_warn()    { printf "\033[1;33m[WARN]\033[0m %s\n" "$1"; }
log_error()   { printf "\033[1;31m[ERROR]\033[0m %s\n" "$1"; exit 1; }

trap 'log_error "Unexpected error at line $LINENO."' ERR

detect_os() {
    if [[ -n "${TERMUX_VERSION:-}" ]]; then
        echo "termux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

OS_TYPE=$(detect_os)
log_info "Detected OS: $OS_TYPE"

# =========================
# AUTO UPDATE GIT
# =========================
auto_update_repo() {
    if ! command -v git >/dev/null 2>&1; then
        log_warn "git not installed, skipping auto-update"
        return
    fi

    if [[ ! -d ".git" ]]; then
        log_warn "Not a git repository, skipping auto-update"
        return
    fi

    log_info "Checking for updates from remote repository..."

    git fetch --quiet || {
        log_warn "git fetch failed, skipping update"
        return
    }

    LOCAL_HASH=$(git rev-parse HEAD)
    REMOTE_HASH=$(git rev-parse @{u} 2>/dev/null || echo "")

    if [[ -z "$REMOTE_HASH" ]]; then
        log_warn "No upstream branch set, skipping update"
        return
    fi

    if [[ "$LOCAL_HASH" != "$REMOTE_HASH" ]]; then
        log_warn "Update detected, pulling latest changes..."

        if git pull --rebase --autostash; then
            log_success "Repository updated successfully"

            log_info "Restarting script to apply updates..."
            exec "$0" "$@"
        else
            log_error "git pull failed"
        fi
    else
        log_success "Already up-to-date"
    fi
}

download_file() {
    local url="$1"
    local output="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 3 --retry-delay 2 -o "$output" "$url" || return 1
    elif command -v wget >/dev/null 2>&1; then
        wget -q --tries=3 -O "$output" "$url" || return 1
    else
        log_error "Neither curl nor wget available."
    fi
}

install_dependencies() {
    case "$OS_TYPE" in
        termux)
            pkg update -y || log_warn "pkg update failed"
            pkg upgrade -y || log_warn "pkg upgrade failed"
            pkg install -y python git curl wget || log_error "Failed installing dependencies"
            ;;
        debian|linux)
            sudo apt update -y
            sudo apt install -y \
                python3 python3-venv python3-pip \
                git curl wget build-essential
            ;;
        macos)
            if ! command -v brew >/dev/null 2>&1; then
                log_error "Homebrew not installed"
            fi
            brew update
            brew install python
            ;;
        *)
            log_error "Unsupported OS"
            ;;
    esac

    log_success "Dependencies installed"
}

ensure_python() {
    if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
        log_error "Python3 not found"
    fi

    log_success "Python detected: $($PYTHON_BIN --version)"
}

bootstrap_pip() {
    local PY="$1"

    if [[ "$OS_TYPE" == "termux" ]]; then
        log_warn "Skipping pip bootstrap on Termux"
        return 0
    fi

    log_warn "pip missing — attempting recovery"

    if "$PY" -m ensurepip --upgrade >/dev/null 2>&1; then
        log_success "pip restored via ensurepip"
        return
    fi

    download_file "$GETPIP_URL" get-pip.py || log_error "Download failed"
    "$PY" get-pip.py || log_error "pip install failed"
    rm -f get-pip.py

    log_success "pip installed via bootstrap"
}

check_pip() {
    local PY="$1"

    if ! "$PY" -m pip --version >/dev/null 2>&1; then
        if [[ "$OS_TYPE" == "termux" ]]; then
            log_error "pip missing in Termux. Run: pkg install python"
        else
            bootstrap_pip "$PY"
        fi
    fi
}

setup_environment() {
    if [[ "$OS_TYPE" == "termux" ]]; then
        log_info "Termux detected — skipping virtualenv"

        check_pip "$PYTHON_BIN"

        "$PYTHON_BIN" -m pip install --upgrade setuptools wheel || \
            log_warn "Setuptools upgrade failed"

        ACTIVE_PYTHON="$PYTHON_BIN"
    else
        if [[ ! -d "$VENV_DIR" ]]; then
            log_info "Creating virtualenv"
            "$PYTHON_BIN" -m venv "$VENV_DIR"
        fi

        # shellcheck disable=SC1091
        source "$VENV_DIR/bin/activate"

        ACTIVE_PYTHON="python"

        check_pip "$ACTIVE_PYTHON"
        "$ACTIVE_PYTHON" -m pip install --upgrade pip setuptools wheel
    fi

    log_success "Python environment ready"
}

install_requirements() {
    [[ -f requirements.txt ]] || log_error "requirements.txt not found"

    log_info "Installing dependencies"

    if ! "$ACTIVE_PYTHON" -m pip install \
        --no-cache-dir \
        --prefer-binary \
        -r requirements.txt; then

        log_warn "Retrying with fallback..."

        "$ACTIVE_PYTHON" -m pip install \
            --no-cache-dir \
            --no-build-isolation \
            -r requirements.txt || \
            log_error "Install failed"
    fi

    log_success "Requirements installed"
}

install_extra_packages() {
    log_info "Installing pycryptodome"

    "$ACTIVE_PYTHON" -m pip uninstall -y crypto pycrypto >/dev/null 2>&1 || true

    "$ACTIVE_PYTHON" -m pip install --no-cache-dir pycryptodome || \
        log_error "pycryptodome failed"

    log_success "pycryptodome installed"
}

run_main() {
    [[ -f main.py ]] || log_error "main.py not found"

    log_info "Running main.py"
    "$ACTIVE_PYTHON" main.py
    log_success "Done"
}

main() {
    auto_update_repo "$@"
    install_dependencies
    ensure_python
    setup_environment
    install_requirements
    install_extra_packages
    run_main
}

main "$@"
