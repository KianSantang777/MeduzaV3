#!/usr/bin/env bash
set -Eeuo pipefail

PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV_DIR="${VENV_DIR:-venv}"
GETPIP_URL="https://bootstrap.pypa.io/get-pip.py"

log_info()    { printf "\033[0;34m[INFO]\033[0m %s\n" "$1"; }
log_success() { printf "\033[0;32m[OK]\033[0m %s\n" "$1"; }
log_warn()    { printf "\033[0;33m[WARN]\033[0m %s\n" "$1"; }
log_error()   { printf "\033[0;31m[ERROR]\033[0m %s\n" "$1"; exit 1; }

trap 'log_error "Unexpected error at line $LINENO"' ERR

cleanup() {
    [[ -f "get-pip.py" ]] && rm -f get-pip.py
}
trap cleanup EXIT

detect_os() {
    if [[ -n "${TERMUX_VERSION:-}" ]]; then
        echo "termux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/redhat-release ]]; then
        echo "redhat"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

OS_TYPE=$(detect_os)

auto_update_repo() {
    command -v git >/dev/null 2>&1 || return

    [[ -d ".git" ]] || return

    log_info "Checking updates"

    git fetch --quiet 2>/dev/null || return

    LOCAL_HASH=$(git rev-parse HEAD)
    REMOTE_HASH=$(git rev-parse @{u} 2>/dev/null || echo "")

    [[ -z "$REMOTE_HASH" ]] && return

    if [[ "$LOCAL_HASH" != "$REMOTE_HASH" ]]; then
        log_info "Updating repository"
        git pull --rebase --autostash --quiet 2>/dev/null || {
            log_warn "Update failed"
            return
        }
        log_success "Repository updated"
        log_info "Restarting"
        exec "$0" "${SCRIPT_ARGS[@]}"
    fi
}

fix_pip_network() {
    mkdir -p ~/.config/pip
    cat > ~/.config/pip/pip.conf <<EOF
[global]
timeout = 60
retries = 5
index-url = https://pypi.org/simple
trusted-host = pypi.org
              files.pythonhosted.org
EOF
    export PIP_DEFAULT_TIMEOUT=60
}

download_file() {
    local url="$1"
    local output="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 3 -o "$output" "$url" || return 1
    elif command -v wget >/dev/null 2>&1; then
        wget -q --tries=3 -O "$output" "$url" || return 1
    else
        return 1
    fi
}

install_dependencies() {
    log_info "Installing dependencies"

    case "$OS_TYPE" in
        termux)
            pkg update -y >/dev/null 2>&1 || true
            pkg install -y python git curl wget ca-certificates >/dev/null 2>&1 || \
                log_error "Failed to install packages"
            ;;
        debian)
            sudo apt update -y >/dev/null 2>&1 || true
            sudo apt install -y python3 python3-venv python3-pip git curl wget build-essential >/dev/null 2>&1 || \
                log_error "Failed to install packages"
            ;;
        redhat)
            sudo dnf install -y python3 python3-pip git curl wget gcc >/dev/null 2>&1 || \
                log_error "Failed to install packages"
            ;;
        macos)
            command -v brew >/dev/null 2>&1 || log_error "Homebrew not found"
            brew update >/dev/null 2>&1 || true
            brew install python@3 >/dev/null 2>&1 || true
            ;;
        *)
            log_warn "Please install manually: python3 python3-venv python3-pip git curl wget"
            ;;
    esac

    log_success "Dependencies ready"
}

ensure_python() {
    command -v "$PYTHON_BIN" >/dev/null 2>&1 || \
        log_error "Python not found"
}

bootstrap_pip() {
    local py="$1"

    if "$py" -m ensurepip --upgrade >/dev/null 2>&1; then
        return
    fi

    download_file "$GETPIP_URL" "get-pip.py" || \
        log_error "Download failed"

    "$py" get-pip.py >/dev/null 2>&1 || \
        log_error "pip installation failed"
}

check_pip() {
    local py="$1"

    if ! "$py" -m pip --version >/dev/null 2>&1; then
        if [[ "$OS_TYPE" == "termux" ]]; then
            log_error "pip not found"
        else
            bootstrap_pip "$py"
        fi
    fi
}

setup_environment() {
    fix_pip_network

    if [[ "$OS_TYPE" == "termux" ]]; then
        ACTIVE_PYTHON="$PYTHON_BIN"
        check_pip "$ACTIVE_PYTHON"
    else
        if [[ ! -d "$VENV_DIR" ]]; then
            "$PYTHON_BIN" -m venv "$VENV_DIR"
        fi

        source "$VENV_DIR/bin/activate"
        ACTIVE_PYTHON="python"

        check_pip "$ACTIVE_PYTHON"
        "$ACTIVE_PYTHON" -m pip install --quiet --upgrade pip
    fi

    "$ACTIVE_PYTHON" -m pip install --quiet --no-cache-dir setuptools wheel

    log_success "Environment ready"
}

install_requirements() {
    [[ -f requirements.txt ]] || log_error "requirements.txt not found"
    [[ -s requirements.txt ]] || log_error "requirements.txt is empty"

    log_info "Installing requirements"

    "$ACTIVE_PYTHON" -m pip install \
        --no-cache-dir \
        --prefer-binary \
        --retries 5 \
        --timeout 60 \
        -r requirements.txt >/dev/null 2>&1 || \
        log_error "Installation failed"

    log_success "Requirements installed"
}

install_extra_packages() {
    log_info "Installing pycryptodome"

    "$ACTIVE_PYTHON" -m pip uninstall -y crypto pycrypto >/dev/null 2>&1 || true
    "$ACTIVE_PYTHON" -m pip install --quiet --no-cache-dir pycryptodome || \
        log_error "pycryptodome installation failed"

    log_success "Extra packages installed"
}

run_main() {
    [[ -f main.py ]] || log_error "main.py not found"

    log_info "Starting main.py"
    "$ACTIVE_PYTHON" main.py
}

main() {
    printf "\n"
    printf "\033[1;36m%s\033[0m\n" "CHK Environment Setup"
    printf "\033[0;36m%s\033[0m\n" "======================"
    printf "\n"

    auto_update_repo
    install_dependencies
    ensure_python
    setup_environment
    install_requirements
    install_extra_packages
    run_main

    printf "\n"
    log_success "Done"
    printf "\n"
}

SCRIPT_ARGS=("$@")
main "$@"
