#!/usr/bin/env bash
set -Eeuo pipefail

PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV_DIR="${VENV_DIR:-venv}"
GETPIP_URL="https://bootstrap.pypa.io/get-pip.py"

log_info()    { printf "\033[0;34m[INFO]\033[0m %s\n" "$1"; }
log_success() { printf "\033[0;32m[OK]\033[0m %s\n" "$1"; }
log_warn()    { printf "\033[0;33m[WARN]\033[0m %s\n" "$1"; }
log_error()   { printf "\033[0;31m[ERROR]\033[0m %s\n" "$1"; exit 1; }

cleanup() {
    [[ -f "get-pip.py" ]] && rm -f get-pip.py 2>/dev/null || true
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
    command -v git >/dev/null 2>&1 || return 0

    [[ -d ".git" ]] || return 0

    log_info "Checking updates"

    git fetch --quiet 2>/dev/null || return 0

    LOCAL_HASH=$(git rev-parse HEAD 2>/dev/null) || return 0
    REMOTE_HASH=$(git rev-parse @{u} 2>/dev/null || echo "")

    [[ -z "$REMOTE_HASH" ]] && return 0

    if [[ "$LOCAL_HASH" != "$REMOTE_HASH" ]]; then
        log_info "Updating repository"
        if git pull --rebase --autostash --quiet 2>/dev/null; then
            log_success "Repository updated"
            log_info "Restarting"
            exec "$0" "${SCRIPT_ARGS[@]}"
        else
            log_warn "Update failed"
            return 0
        fi
    fi

    return 0
}

fix_pip_network() {
    mkdir -p ~/.config/pip 2>/dev/null || true

    cat > ~/.config/pip/pip.conf <<EOF
[global]
timeout = 60
retries = 5
index-url = https://pypi.org/simple
trusted-host = pypi.org
              files.pythonhosted.org
EOF

    export PIP_DEFAULT_TIMEOUT=60

    return 0
}

download_file() {
    local url="$1"
    local output="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 3 -o "$output" "$url" 2>/dev/null && return 0 || return 1
    elif command -v wget >/dev/null 2>&1; then
        wget -q --tries=3 -O "$output" "$url" 2>/dev/null && return 0 || return 1
    fi

    return 1
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
            if ! command -v brew >/dev/null 2>&1; then
                log_error "Homebrew not found"
            fi
            brew update >/dev/null 2>&1 || true
            brew install python@3 >/dev/null 2>&1 || true
            ;;
        *)
            log_warn "Please install manually: python3 python3-venv python3-pip git curl wget"
            ;;
    esac

    log_success "Dependencies ready"
    return 0
}

ensure_python() {
    if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
        log_error "Python not found"
    fi
    return 0
}

bootstrap_pip() {
    local py="$1"

    if "$py" -m ensurepip --upgrade >/dev/null 2>&1; then
        return 0
    fi

    if ! download_file "$GETPIP_URL" "get-pip.py"; then
        log_error "Download failed"
    fi

    if ! "$py" get-pip.py >/dev/null 2>&1; then
        log_error "pip installation failed"
    fi

    return 0
}

check_pip() {
    local py="$1"

    if "$py" -m pip --version >/dev/null 2>&1; then
        return 0
    fi

    if [[ "$OS_TYPE" == "termux" ]]; then
        log_error "pip not found"
    fi

    bootstrap_pip "$py"
    return 0
}

setup_environment() {
    fix_pip_network

    if [[ "$OS_TYPE" == "termux" ]]; then
        ACTIVE_PYTHON="$PYTHON_BIN"
        check_pip "$ACTIVE_PYTHON"
    else
        if [[ ! -d "$VENV_DIR" ]]; then
            "$PYTHON_BIN" -m venv "$VENV_DIR" || log_error "Failed to create venv"
        fi

        source "$VENV_DIR/bin/activate"
        ACTIVE_PYTHON="python"

        check_pip "$ACTIVE_PYTHON"
        "$ACTIVE_PYTHON" -m pip install --quiet --upgrade pip 2>/dev/null || true
    fi

    "$ACTIVE_PYTHON" -m pip install --quiet --no-cache-dir setuptools wheel 2>/dev/null || true

    log_success "Environment ready"
    return 0
}

install_requirements() {
    if [[ ! -f requirements.txt ]]; then
        log_error "requirements.txt not found"
    fi

    if [[ ! -s requirements.txt ]]; then
        log_error "requirements.txt is empty"
    fi

    log_info "Installing requirements"

    if ! "$ACTIVE_PYTHON" -m pip install \
        --no-cache-dir \
        --prefer-binary \
        --retries 5 \
        --timeout 60 \
        -r requirements.txt >/dev/null 2>&1; then
        log_error "Installation failed"
    fi

    log_success "Requirements installed"
    return 0
}

install_extra_packages() {
    log_info "Installing pycryptodome"

    "$ACTIVE_PYTHON" -m pip uninstall -y crypto pycrypto >/dev/null 2>&1 || true

    if ! "$ACTIVE_PYTHON" -m pip install --quiet --no-cache-dir pycryptodome 2>/dev/null; then
        log_error "pycryptodome installation failed"
    fi

    log_success "Extra packages installed"
    return 0
}

run_main() {
    if [[ ! -f main.py ]]; then
        log_error "main.py not found"
    fi

    log_info "Starting main.py"
    "$ACTIVE_PYTHON" main.py
    return 0
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
    return 0
}

SCRIPT_ARGS=("$@")
main "$@"
