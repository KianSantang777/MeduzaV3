#!/usr/bin/env bash

###############################################################################
# UNIVERSAL PYTHON 3.12.2 INSTALLER
# Compatible: Termux, Ubuntu, Debian, Linux, macOS (Intel/ARM)
# - No virtualenv on Termux
# - Virtualenv on others
# - Fully audited & optimized
###############################################################################

set -Eeuo pipefail

PYTHON_VERSION="3.12.2"
PYTHON_BIN="python3.12"
PYTHON_TAR="Python-${PYTHON_VERSION}.tgz"
PYTHON_SRC_DIR="Python-${PYTHON_VERSION}"
VENV_DIR="venv"

###############################################################################
# Logging
###############################################################################

log_info()    { printf "\033[1;34m[INFO]\033[0m %s\n" "$1"; }
log_success() { printf "\033[1;32m[SUCCESS]\033[0m %s\n" "$1"; }
log_warn()    { printf "\033[1;33m[WARNING]\033[0m %s\n" "$1"; }
log_error()   { printf "\033[1;31m[ERROR]\033[0m %s\n" "$1"; exit 1; }

trap 'log_error "Unexpected error at line $LINENO."' ERR

###############################################################################
# OS Detection
###############################################################################

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

###############################################################################
# CPU Core Detection
###############################################################################

detect_cores() {
    if command -v nproc >/dev/null 2>&1; then
        nproc
    elif [[ "$OS_TYPE" == "macos" ]]; then
        sysctl -n hw.ncpu
    else
        echo 2
    fi
}

CPU_CORES=$(detect_cores)

###############################################################################
# Install Dependencies
###############################################################################

install_dependencies() {

    case "$OS_TYPE" in
        termux)
            pkg update -y
            pkg upgrade -y
            pkg install -y \
                git nano wget curl clang make \
                openssl libffi zlib
            ;;

        debian|linux)
            sudo apt update -y
            sudo apt install -y \
                git nano wget curl build-essential \
                libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
                libsqlite3-dev libffi-dev libncursesw5-dev \
                xz-utils tk-dev uuid-dev
            ;;

        macos)
            if ! command -v brew >/dev/null 2>&1; then
                log_error "Homebrew not found. Install from https://brew.sh/"
            fi

            brew update
            brew install git nano wget openssl readline sqlite3 xz zlib

            export LDFLAGS="-L$(brew --prefix openssl)/lib"
            export CPPFLAGS="-I$(brew --prefix openssl)/include"
            ;;

        *)
            log_error "Unsupported OS."
            ;;
    esac

    log_success "System dependencies installed."
}

###############################################################################
# Install Python 3.12.2 (if missing)
###############################################################################

install_python() {

    if command -v "$PYTHON_BIN" >/dev/null 2>&1; then
        INSTALLED_VERSION=$($PYTHON_BIN --version | awk '{print $2}')
        if [[ "$INSTALLED_VERSION" == "$PYTHON_VERSION" ]]; then
            log_success "Python $PYTHON_VERSION already installed."
            return
        fi
    fi

    log_info "Downloading Python $PYTHON_VERSION..."
    wget -q https://www.python.org/ftp/python/${PYTHON_VERSION}/${PYTHON_TAR}

    tar -xf "$PYTHON_TAR"
    cd "$PYTHON_SRC_DIR"

    ./configure --enable-optimizations --with-ensurepip=install
    make -j"$CPU_CORES"

    if [[ "$OS_TYPE" == "termux" ]]; then
        make install
    else
        sudo make altinstall
    fi

    cd ..
    rm -rf "$PYTHON_SRC_DIR" "$PYTHON_TAR"

    log_success "Python $PYTHON_VERSION installed."
}

###############################################################################
# Setup Environment
###############################################################################

setup_environment() {

    if [[ "$OS_TYPE" == "termux" ]]; then
        log_info "Termux detected: skipping virtual environment."
        "$PYTHON_BIN" -m ensurepip --upgrade
        "$PYTHON_BIN" -m pip install --upgrade pip setuptools wheel
        ACTIVE_PYTHON="$PYTHON_BIN"
    else
        if [[ ! -d "$VENV_DIR" ]]; then
            log_info "Creating virtual environment..."
            "$PYTHON_BIN" -m venv "$VENV_DIR"
        fi

        # shellcheck disable=SC1091
        source "$VENV_DIR/bin/activate"
        python -m pip install --upgrade pip setuptools wheel
        ACTIVE_PYTHON="python"
    fi

    log_success "Python environment ready."
}

###############################################################################
# Install Packages
###############################################################################

install_packages() {

    log_info "Installing Python packages..."

    "$ACTIVE_PYTHON" -m pip install --upgrade \
        requests \
        "requests[socks]" \
        colorama \
        tqdm \
        bs4 \
        cloudscraper \
        "python-socketio[client]" \
        websocket-client \
        faker \
        pyfiglet \
        portalocker \
        "httpx[http2]" \
        psutil \
        pycryptodome \
        pyarmor \
        aiohttp \
        user_agent

    log_success "All packages installed."
}

###############################################################################
# Run main.py
###############################################################################

run_main() {

    if [[ ! -f "main.py" ]]; then
        log_error "main.py not found in current directory."
    fi

    log_info "Executing main.py..."

    if ! "$ACTIVE_PYTHON" main.py; then
        log_error "main.py execution failed."
    fi

    log_success "Program finished successfully."
}

###############################################################################
# MAIN
###############################################################################

main() {
    install_dependencies
    install_python
    setup_environment
    install_packages
    run_main
}

main
