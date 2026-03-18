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

download_file() {
    local url="$1"
    local output="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$output"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$output"
    else
        log_error "Neither curl nor wget available."
    fi
}

install_dependencies() {
    case "$OS_TYPE" in
        termux)
            pkg update -y
            pkg upgrade -y
            pkg install -y python git curl wget
            ;;
        debian|linux)
            sudo apt update -y
            sudo apt install -y \
                python3 python3-venv python3-pip \
                git curl wget build-essential
            ;;
        macos)
            if ! command -v brew >/dev/null 2>&1; then
                log_error "Homebrew not installed (https://brew.sh)"
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
        log_error "Python3 not found after dependency install."
    fi

    log_success "Python detected: $($PYTHON_BIN --version)"
}

bootstrap_pip() {
    local PY="$1"

    log_warn "pip missing — attempting recovery"

    if "$PY" -m ensurepip --upgrade >/dev/null 2>&1; then
        log_success "pip restored via ensurepip"
        return
    fi

    log_warn "ensurepip failed — downloading get-pip.py"

    download_file "$GETPIP_URL" get-pip.py
    "$PY" get-pip.py
    rm -f get-pip.py

    log_success "pip installed via bootstrap"
}

check_pip() {
    local PY="$1"

    if ! "$PY" -m pip --version >/dev/null 2>&1; then
        bootstrap_pip "$PY"
    fi
}

setup_environment() {
    if [[ "$OS_TYPE" == "termux" ]]; then
        log_info "Termux detected — no virtualenv"

        check_pip "$PYTHON_BIN"
        "$PYTHON_BIN" -m pip install --upgrade pip setuptools wheel

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
    if [[ ! -f requirements.txt ]]; then
        log_error "requirements.txt not found"
    fi

    log_info "Installing Python dependencies"

    if ! "$ACTIVE_PYTHON" -m pip install -r requirements.txt; then
        log_warn "Retrying installation"
        "$ACTIVE_PYTHON" -m pip install -r requirements.txt
    fi

    log_success "Requirements installed"
}

install_extra_packages() {
    log_info "Installing extra packages (pycryptodome)"

    # cleanup konflik lama
    "$ACTIVE_PYTHON" -m pip uninstall -y crypto pycrypto >/dev/null 2>&1 || true

    if ! "$ACTIVE_PYTHON" -m pip install pycryptodome; then
        log_warn "Retry installing pycryptodome"
        "$ACTIVE_PYTHON" -m pip install pycryptodome
    fi

    log_success "pycryptodome installed"
}

run_main() {
    if [[ ! -f main.py ]]; then
        log_error "main.py not found"
    fi

    log_info "Executing main.py"
    "$ACTIVE_PYTHON" main.py
    log_success "Program finished"
}

main() {
    install_dependencies
    ensure_python
    setup_environment
    install_requirements
    install_extra_packages
    run_main
}

main
