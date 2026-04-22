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
        log_warn "Not a git repository"
        return
    fi

    log_info "Checking for updates..."

    git fetch --quiet || {
        log_warn "git fetch failed"
        return
    }

    LOCAL_HASH=$(git rev-parse HEAD)
    REMOTE_HASH=$(git rev-parse @{u} 2>/dev/null || echo "")

    if [[ -z "$REMOTE_HASH" ]]; then
        log_warn "No upstream branch"
        return
    fi

    if [[ "$LOCAL_HASH" != "$REMOTE_HASH" ]]; then
        log_warn "Update found, pulling..."

        if git pull --rebase --autostash; then
            log_success "Updated successfully"
            exec "$0" "$@"
        else
            log_error "git pull failed"
        fi
    else
        log_success "Already up-to-date"
    fi
}

# =========================
# NETWORK FIX (CRITICAL)
# =========================
fix_pip_network() {
    log_info "Configuring pip network..."

    mkdir -p ~/.config/pip

    cat > ~/.config/pip/pip.conf <<EOF
[global]
timeout = 60
index-url = https://pypi.org/simple
trusted-host =
    pypi.org
    files.pythonhosted.org
retries = 5
EOF

    export PIP_DEFAULT_TIMEOUT=60
    export PYTHONHTTPSVERIFY=0

    log_success "pip network ready"
}

download_file() {
    local url="$1"
    local output="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 3 --retry-delay 2 -o "$output" "$url" || return 1
    elif command -v wget >/dev/null 2>&1; then
        wget -q --tries=3 -O "$output" "$url" || return 1
    else
        log_error "curl/wget not found"
    fi
}

install_dependencies() {
    case "$OS_TYPE" in
        termux)
            pkg update -y || log_warn "update failed"
            pkg upgrade -y || log_warn "upgrade failed"
            pkg install -y python git curl wget ca-certificates || \
                log_error "dependency install failed"
            ;;
        debian|linux)
            sudo apt update -y
            sudo apt install -y python3 python3-venv python3-pip git curl wget build-essential
            ;;
        macos)
            command -v brew >/dev/null || log_error "Install Homebrew first"
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
    command -v "$PYTHON_BIN" >/dev/null || log_error "Python not found"
    log_success "Using: $($PYTHON_BIN --version)"
}

bootstrap_pip() {
    local PY="$1"

    if [[ "$OS_TYPE" == "termux" ]]; then
        log_warn "Skipping pip bootstrap (Termux safe mode)"
        return
    fi

    log_warn "pip missing, recovering..."

    if "$PY" -m ensurepip --upgrade >/dev/null 2>&1; then
        return
    fi

    download_file "$GETPIP_URL" get-pip.py || log_error "Download failed"
    "$PY" get-pip.py || log_error "pip install failed"
    rm -f get-pip.py
}

check_pip() {
    local PY="$1"

    if ! "$PY" -m pip --version >/dev/null 2>&1; then
        if [[ "$OS_TYPE" == "termux" ]]; then
            log_error "pip missing. Fix: pkg install python"
        else
            bootstrap_pip "$PY"
        fi
    fi
}

install_core_packages() {
    log_info "Installing core packages..."

    if ! "$ACTIVE_PYTHON" -m pip install --no-cache-dir setuptools wheel; then
        log_warn "pip failed, trying fallback"

        if [[ "$OS_TYPE" == "termux" ]]; then
            pkg install -y python-setuptools || log_warn "fallback failed"
        fi
    fi
}

setup_environment() {
    fix_pip_network

    if [[ "$OS_TYPE" == "termux" ]]; then
        log_info "Termux mode (no venv)"

        check_pip "$PYTHON_BIN"
        ACTIVE_PYTHON="$PYTHON_BIN"

        install_core_packages
    else
        if [[ ! -d "$VENV_DIR" ]]; then
            log_info "Creating venv"
            "$PYTHON_BIN" -m venv "$VENV_DIR"
        fi

        source "$VENV_DIR/bin/activate"
        ACTIVE_PYTHON="python"

        check_pip "$ACTIVE_PYTHON"
        "$ACTIVE_PYTHON" -m pip install --upgrade pip
        install_core_packages
    fi

    log_success "Environment ready"
}

install_requirements() {
    [[ -f requirements.txt ]] || log_error "requirements.txt missing"

    log_info "Installing requirements..."

    if ! "$ACTIVE_PYTHON" -m pip install \
        --no-cache-dir \
        --prefer-binary \
        --retries 5 \
        --timeout 60 \
        -r requirements.txt; then

        log_warn "Retry with fallback..."

        "$ACTIVE_PYTHON" -m pip install \
            --no-cache-dir \
            --index-url https://pypi.org/simple \
            --trusted-host pypi.org \
            --trusted-host files.pythonhosted.org \
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
