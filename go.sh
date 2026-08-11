#!/usr/bin/env bash
set -Eeo pipefail

VENV_DIR="${VENV_DIR:-venv}"
BRANCH="${BRANCH:-main}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

i() { printf "${CYAN}▸${RESET} %s\n" "$1"; }
s() { printf "${GREEN}✓${RESET} %s\n" "$1"; }
w() { printf "${YELLOW}!${RESET} %s\n" "$1"; }
e() { printf "${RED}✗${RESET} %s\n" "$1"; exit 1; }

detect_os() {
    if [[ -n "${TERMUX_VERSION:-}" ]] || [[ -d "/data/data/com.termux" ]]; then
        echo "termux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux"* ]]; then
        if [[ -f /etc/redhat-release ]]; then
            echo "redhat"
        elif [[ -f /etc/debian_version ]]; then
            echo "debian"
        else
            echo "linux"
        fi
    else
        echo "unknown"
    fi
}

install_system_pkg() {
    case "$OS_TYPE" in
        termux) pkg update -y >/dev/null 2>&1 && pkg install -y "$@" ;;
        debian) sudo apt-get update -y >/dev/null 2>&1 && sudo apt-get install -y "$@" ;;
        redhat) sudo dnf install -y "$@" >/dev/null 2>&1 || sudo yum install -y "$@" ;;
        macos) command -v brew &> /dev/null && brew install "$@" ;;
    esac
}

check_git() {
    if command -v git &> /dev/null; then return 0; fi
    i "Installing git..."
    case "$OS_TYPE" in
        termux) install_system_pkg git ;;
        debian) install_system_pkg git ;;
        redhat) install_system_pkg git ;;
        macos) brew install git 2>/dev/null || w "Install git manually" ;;
        *) w "Git not found, install manually"; return 1 ;;
    esac
    command -v git &> /dev/null || { w "Git installation failed"; return 1; }
}

check_python() {
    for py in python3 python python3.12 python3.11 python3.10 python3.9; do
        if command -v $py &> /dev/null; then
            PYTHON_BIN=$py
            PYTHON_VERSION=$($py -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
            return 0
        fi
    done
    return 1
}

install_python() {
    i "Installing Python..."
    case "$OS_TYPE" in
        termux)
            install_system_pkg python python-pip
            ;;
        debian)
            install_system_pkg python3 python3-pip python3-venv
            ;;
        redhat)
            install_system_pkg python3 python3-pip
            ;;
        macos)
            if command -v brew &> /dev/null; then
                brew install python
            else
                e "Install Python from python.org"
            fi
            ;;
        *)
            e "Unsupported OS. Install Python 3.8+ manually"
            ;;
    esac
    check_python || e "Python installation failed"
}

check_pip() {
    if $PYTHON_BIN -m pip --version &> /dev/null; then return 0; fi
    i "Installing pip..."
    $PYTHON_BIN -m ensurepip --upgrade &> /dev/null && return 0
    e "pip installation failed"
}

setup_venv() {
    i "Setting up virtual environment..."
    [[ -d "$VENV_DIR" ]] && rm -rf "$VENV_DIR"
    $PYTHON_BIN -m venv "$VENV_DIR" || e "Failed to create venv"
    source "$VENV_DIR/bin/activate"
    s "Virtual environment ready"
}

install_packages() {
    i "Installing packages..."
    PACKAGES=(
        "requests"
        "colorama"
        "tqdm"
        "faker"
        "requests_toolbelt"
        "cython"
        "pyfiglet"
        "python-socketio"
    )
    for pkg in "${PACKAGES[@]}"; do
        printf "  ${YELLOW}▸${RESET} %-20s " "$pkg"
        if python -m pip install --no-cache-dir "$pkg" -q 2>/dev/null; then
            echo "${GREEN}✓${RESET}"
        else
            echo "${YELLOW}⚠${RESET}"
        fi
    done
    s "Packages installed"
}

check_updates() {
    if ! command -v git &> /dev/null; then
        i "Git not available, skip update check"
        return 0
    fi
    if [[ ! -d ".git" ]]; then
        i "Not a git repo, skip update check"
        return 0
    fi
    if ! git remote get-url origin &> /dev/null; then
        i "No remote configured, skip update check"
        return 0
    fi

    i "Checking updates..."
    if ! git fetch origin "$BRANCH" --quiet 2>/dev/null; then
        w "Fetch failed"
        return 0
    fi

    LOCAL=$(git rev-parse HEAD 2>/dev/null || echo "")
    REMOTE=$(git rev-parse "origin/$BRANCH" 2>/dev/null || echo "")

    if [[ -z "$LOCAL" ]] || [[ -z "$REMOTE" ]]; then
        return 0
    fi

    if [[ "$LOCAL" != "$REMOTE" ]]; then
        echo ""
        echo "  ┌─────────────────────────────────────┐"
        echo "  │         UPDATE AVAILABLE              │"
        echo "  └─────────────────────────────────────┘"
        echo ""
        read -p "  Update now? [Y/n]: " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            i "Updating..."
            if git pull origin "$BRANCH" --autostash 2>/dev/null; then
                s "Updated!"
                exec "$0" "${SCRIPT_ARGS[@]}"
            else
                e "Update failed"
            fi
        fi
    else
        s "Up to date"
    fi
}

check_files() {
    i "Checking files..."
    if [[ -f "run.py" ]]; then
        s "run.py"
    else
        e "Missing: run.py"
    fi

    BINARY=$(find . -maxdepth 1 \( -name "*.so" -o -name "*.pyd" \) 2>/dev/null | head -n1)
    if [[ -n "$BINARY" ]]; then
        s "Binary: $(basename "$BINARY")"
    else
        w "No binary found"
        if [[ -f "build.py" ]]; then
            read -p "  Build now? [Y/n]: " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                if python build.py >/dev/null 2>&1; then
                    s "Build complete"
                else
                    w "Build failed, continue anyway"
                fi
            fi
        fi
    fi
}

main() {
    SCRIPT_ARGS=("$@")

    echo ""
    echo "  ┌─────────────────────────────────────┐"
    echo "  │           MeduzaV3                  │"
    echo "  │        Tools CC Checker             │"
    echo "  │   t.me/xqndrs │ t.me/xqndrs66       │"
    echo "  └─────────────────────────────────────┘"
    echo ""
    echo "  OS: $OS_TYPE"
    echo ""

    if ! check_python; then
        install_python
    fi
    s "Python: $PYTHON_VERSION"

    check_git || true
    check_pip || true

    setup_venv
    install_packages
    check_updates
    check_files

    echo ""
    echo "  ┌─────────────────────────────────────┐"
    echo "  │         Ready to start!             │"
    echo "  └─────────────────────────────────────┘"
    echo ""
    read -p "  Start? [Y/n]: " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        source "$VENV_DIR/bin/activate"
        python3 run.py "${SCRIPT_ARGS[@]}"
    else
        i "Run './go.sh' to start later"
    fi
}

trap 'echo ""; i "Interrupted."; exit 130' INT
main "$@"
