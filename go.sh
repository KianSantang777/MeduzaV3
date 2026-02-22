#!/usr/bin/env bash

###############################################################################
# Universal Python 3.12.2 Auto Installer
# Compatible: Termux, Ubuntu, Debian, Linux, macOS (Intel & Apple Silicon)
# - No virtualenv for Termux
# - Virtualenv for other systems
# - Full error handling
# - Idempotent
###############################################################################

set -Eeuo pipefail

PYTHON_VERSION="3.12.2"
PYTHON_TAR="Python-${PYTHON_VERSION}.tgz"
PYTHON_SRC_DIR="Python-${PYTHON_VERSION}"
VENV_DIR="venv"

###############################################################################
# Pretty Output
###############################################################################
info()    { echo -e "\033[1;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
warning() { echo -e "\033[1;33m[WARNING]\033[0m $1"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m $1"; exit 1; }

trap 'error "Unexpected failure occurred at line $LINENO."' ERR

###############################################################################
# Detect OS
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
info "Detected OS: $OS_TYPE"

###############################################################################
# CPU Core Detection (Portable)
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
# Install System Dependencies
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
                error "Homebrew not found. Install it from https://brew.sh/"
            fi

            brew update
            brew install git nano wget openssl readline sqlite3 xz zlib

            # Ensure OpenSSL path for Python build
            export LDFLAGS="-L$(brew --prefix openssl)/lib"
            export CPPFLAGS="-I$(brew --prefix openssl)/include"
            ;;

        *)
            error "Unsupported OS."
            ;;
    esac

    success "System dependencies installed."
}

###############################################################################
# Check Python
###############################################################################
install_python() {

    if command -v python3.12 >/dev/null 2>&1; then
        INSTALLED_VERSION=$(python3.12 --version | awk '{print $2}')
        if [[ "$INSTALLED_VERSION" == "$PYTHON_VERSION" ]]; then
            success "Python $PYTHON_VERSION already installed."
            return
        fi
    fi

    info "Downloading Python $PYTHON_VERSION..."
    wget -q https://www.python.org/ftp/python/${PYTHON_VERSION}/${PYTHON_TAR}

    tar -xf ${PYTHON_TAR}
    cd ${PYTHON_SRC_DIR}

    info "Configuring Python build..."
    ./configure --enable-optimizations --with-ensurepip=install

    info "Compiling using $CPU_CORES cores..."
    make -j"$CPU_CORES"

    if [[ "$OS_TYPE" == "termux" ]]; then
        make install
    else
        sudo make altinstall
    fi

    cd ..
    rm -rf ${PYTHON_SRC_DIR} ${PYTHON_TAR}

    success "Python $PYTHON_VERSION installed successfully."
}

###############################################################################
# Setup Environment
###############################################################################
setup_environment() {

    if [[ "$OS_TYPE" == "termux" ]]; then
        info "Skipping virtual environment (Termux mode)."
        python3.12 -m ensurepip --upgrade
        python3.12 -m pip install --upgrade pip setuptools wheel
    else
        if [[ ! -d "$VENV_DIR" ]]; then
            info "Creating virtual environment..."
            python3.12 -m venv "$VENV_DIR"
        fi

        # shellcheck disable=SC1091
        source "$VENV_DIR/bin/activate"

        python -m pip install --upgrade pip setuptools wheel
    fi

    success "Python environment ready."
}

###############################################################################
# Install Python Packages
###############################################################################
install_packages() {

    info "Installing required Python packages..."

    python -m pip install --upgrade \
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

    success "All Python packages installed successfully."
}

###############################################################################
# Run main.py
###############################################################################
run_main() {

    if [[ ! -f "main.py" ]]; then
        error "main.py not found in current directory."
    fi

    info "Running main.py..."

    if ! python main.py; then
        error "main.py exited with an error."
    fi

    success "Execution completed successfully."
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
