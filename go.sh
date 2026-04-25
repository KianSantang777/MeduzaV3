#!/usr/bin/env bash
set -Eeo pipefail

PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV_DIR="${VENV_DIR:-venv}"
GETPIP_URL="https://bootstrap.pypa.io/get-pip.py"

log_info()    { printf "\033[0;34m[INFO]\033[0m %s\n" "$1"; }
log_success() { printf "\033[0;32m[OK]\033[0m %s\n" "$1"; }
log_warn()    { printf "\033[0;33m[WARN]\033[0m %s\n" "$1"; }
log_error()   { printf "\033[0;31m[ERROR]\033[0m %s\n" "$1"; }

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
        log_warn "Download failed, trying alternative method"
        return 1
    fi

    if ! "$py" get-pip.py >/dev/null 2>&1; then
        log_warn "pip installation failed, trying alternative"
        return 1
    fi

    return 0
}

check_pip() {
    local py="$1"

    if "$py" -m pip --version >/dev/null 2>&1; then
        return 0
    fi

    if [[ "$OS_TYPE" == "termux" ]]; then
        log_warn "pip not found, installing..."
        bootstrap_pip "$py" || log_warn "Bootstrap failed, continuing anyway"
    else
        bootstrap_pip "$py" || log_warn "Bootstrap failed, trying system pip"
    fi

    return 0
}

setup_environment() {
    fix_pip_network

    if [[ "$OS_TYPE" == "termux" ]]; then
        ACTIVE_PYTHON="$PYTHON_BIN"
        check_pip "$ACTIVE_PYTHON"
    else
        if [[ ! -d "$VENV_DIR" ]]; then
            log_info "Creating virtual environment"
            if ! "$PYTHON_BIN" -m venv "$VENV_DIR"; then
                log_warn "Failed to create venv, using system Python"
                ACTIVE_PYTHON="$PYTHON_BIN"
            else
                source "$VENV_DIR/bin/activate"
                ACTIVE_PYTHON="python"
            fi
        else
            source "$VENV_DIR/bin/activate"
            ACTIVE_PYTHON="python"
        fi

        check_pip "$ACTIVE_PYTHON"
        "$ACTIVE_PYTHON" -m pip install --quiet --upgrade pip 2>/dev/null || true
    fi

    "$ACTIVE_PYTHON" -m pip install --quiet --no-cache-dir setuptools wheel 2>/dev/null || true

    log_success "Environment ready"
    return 0
}

install_requirements() {
    if [[ ! -f requirements.txt ]]; then
        log_warn "requirements.txt not found, skipping"
        return 0
    fi

    if [[ ! -s requirements.txt ]]; then
        log_warn "requirements.txt is empty, skipping"
        return 0
    fi

    log_info "Installing requirements"

    if ! "$ACTIVE_PYTHON" -m pip install \
        --no-cache-dir \
        --prefer-binary \
        --retries 5 \
        --timeout 60 \
        -r requirements.txt; then
        log_warn "Some requirements failed, continuing..."
    fi

    log_success "Requirements installed"
    return 0
}

install_extra_packages() {
    log_info "Installing pycryptodome (optional)"

    "$ACTIVE_PYTHON" -m pip uninstall -y crypto pycrypto >/dev/null 2>&1 || true

    # Make pycryptodome optional, not mandatory
    if ! "$ACTIVE_PYTHON" -m pip install --quiet --no-cache-dir pycryptodome 2>/dev/null; then
        log_warn "pycryptodome installation failed (optional for basic operation)"
        log_warn "Encryption will use fallback methods"
    fi

    log_success "Extra packages check complete"
    return 0
}

run_main() {
    if [[ ! -f main.py ]]; then
        log_warn "main.py not found, skipping execution"
        return 0
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

    auto_update_repo || log_warn "Auto-update failed"
    install_dependencies || log_warn "Dependency installation had issues"
    ensure_python || log_error "Python check failed"
    setup_environment || log_error "Environment setup failed"
    install_requirements || log_warn "Requirements installation had issues"
    install_extra_packages || log_warn "Extra packages installation had issues"
    run_main || log_warn "Main execution failed"

    printf "\n"
    log_success "Setup complete"
    printf "\n"
    return 0
}

SCRIPT_ARGS=("$@")
main "$@"
