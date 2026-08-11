#!/usr/bin/env bash
set -Eeo pipefail

VENV_DIR="${VENV_DIR:-venv}"
REPO_URL="https://github.com/KianSantang777/MeduzaV3"
BRANCH="${BRANCH:-main}"
GETPIP_URL="https://bootstrap.pypa.io/get-pip.py"

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
    if [[ -n "${TERMUX_VERSION:-}" ]] || [[ -d "/data/data/com.termux" ]]; then echo "termux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then echo "macos"
    elif [[ "$OSTYPE" == "linux"* ]]; then
        [[ -f /etc/debian_version ]] && echo "debian" || echo "linux"
    else echo "unknown"; fi
}

OS_TYPE=$(detect_os)

download_file() {
    if command -v curl &> /dev/null; then curl -fsSL --retry 3 -o "$2" "$1" 2>/dev/null && return 0; fi
    if command -v wget &> /dev/null; then wget -q --tries=3 -O "$2" "$1" 2>/dev/null && return 0; fi
    return 1
}

install_git() {
    if command -v git &> /dev/null; then return 0; fi
    i "Installing git..."
    case "$OS_TYPE" in
        termux) pkg update -y >/dev/null 2>&1 && pkg install -y git ;;
        debian) sudo apt-get update -y >/dev/null 2>&1 && sudo apt-get install -y git ;;
        redhat) sudo dnf install -y git >/dev/null 2>&1 || sudo yum install -y git ;;
        macos) command -v brew &> /dev/null && brew install git ;;
        *) e "Install git manually";;
    esac
    command -v git &> /dev/null || e "Git installation failed"
}

install_python() {
    for py in python3 python python3.12 python3.11 python3.10 python3.9; do
        if command -v $py &> /dev/null; then PYTHON_BIN=$py; return 0; fi
    done
    i "Installing Python..."
    case "$OS_TYPE" in
        termux) pkg update -y >/dev/null 2>&1 && pkg install -y python python-pip git curl wget ;;
        debian) sudo apt-get update -y >/dev/null 2>&1 && sudo apt-get install -y python3 python3-pip python3-venv git curl wget build-essential ;;
        redhat) sudo dnf install -y python3 python3-pip git curl wget gcc >/dev/null 2>&1 || sudo yum install -y python3 python3-pip git curl wget ;;
        macos) command -v brew &> /dev/null && brew install python git curl wget || e "Install Python from python.org";;
        *) e "Install Python 3.8+ manually";;
    esac
    for py in python3 python; do command -v $py &> /dev/null && PYTHON_BIN=$py && return 0; done
    e "Python installation failed"
}

install_pip() {
    if $PYTHON_BIN -m pip --version &> /dev/null; then return 0; fi
    i "Installing pip..."
    $PYTHON_BIN -m ensurepip --upgrade &> /dev/null && return 0
    download_file "$GETPIP_URL" "get-pip.py" && $PYTHON_BIN get-pip.py &> /dev/null && return 0
    e "pip installation failed"
}

setup_venv() {
    i "Setting up virtual environment..."
    [[ -d "$VENV_DIR" ]] && rm -rf "$VENV_DIR"
    $PYTHON_BIN -m venv "$VENV_DIR" || e "Failed to create venv"
    source "$VENV_DIR/bin/activate"
    python -m pip install --upgrade pip --quiet 2>/dev/null || python -m pip install --upgrade pip
    s "Virtual environment ready"
}

install_packages() {
    i "Installing packages..."
    for pkg in requests colorama tqdm faker requests_toolbelt cython pyfiglet python-socketio; do
        printf "  ${YELLOW}▸${RESET} $pkg... "
        python -m pip install --no-cache-dir "$pkg" --quiet 2>/dev/null && echo "${GREEN}✓${RESET}" || { echo "${YELLOW}retry${RESET}"; python -m pip install --no-cache-dir "$pkg"; }
    done
    s "Packages installed"
}

check_updates() {
    i "Checking updates..."
    if [[ ! -d ".git" ]]; then i "Not a git repo, skipping"; return 0; fi
    if ! git remote get-url origin &> /dev/null; then i "No remote, skipping"; return 0; fi
    git fetch origin $BRANCH --quiet 2>/dev/null || { w "Fetch failed"; return 0; }
    LOCAL=$(git rev-parse HEAD 2>/dev/null || echo "")
    REMOTE=$(git rev-parse origin/$BRANCH 2>/dev/null || echo "")
    [[ -z "$LOCAL" ]] || [[ -z "$REMOTE" ]] && return 0
    if [[ "$LOCAL" != "$REMOTE" ]]; then
        echo ""
        echo "  ┌─────────────────────────────────────┐"
        echo "  │         UPDATE AVAILABLE            │"
        echo "  └─────────────────────────────────────┘"
        echo ""
        read -p "  Update now? [Y/n]: " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            i "Updating..."
            git pull origin $BRANCH --autostash && s "Updated!" || e "Update failed"
            exec "$0" "${SCRIPT_ARGS[@]}"
        fi
    else
        s "Up to date"
    fi
}

check_files() {
    i "Checking files..."
    for f in run.py build.py; do
        if [[ -f "$f" ]]; then s "$f"; else e "Missing: $f"; fi
    done
    BINARY=$(find . -maxdepth 1 \( -name "*.so" -o -name "*.pyd" \) 2>/dev/null | head -1)
    if [[ -n "$BINARY" ]]; then s "Binary: $(basename $BINARY)"
    else
        w "No binary found"
        read -p "  Build now? [Y/n]: " -n 1 -r
        echo ""
        [[ ! $REPLY =~ ^[Nn]$ ]] && { python build.py || e "Build failed"; }
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

    install_git; s "Git ready"
    install_python; s "Python: $($PYTHON_BIN --version)"
    install_pip; s "pip ready"

    mkdir -p ~/.config/pip 2>/dev/null
    cat > ~/.config/pip/pip.conf <<< '[global]
timeout = 60
retries = 5
index-url = https://pypi.org/simple
trusted-host = pypi.org files.pythonhosted.org' 2>/dev/null || true

    setup_venv
    install_packages
    check_updates
    check_files

    echo ""
    echo "  ┌─────────────────────────────────────┐"
    echo "  │        Ready to start!              │"
    echo "  └─────────────────────────────────────┘"
    echo ""
    read -p "  Start? [Y/n]: " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        source "$VENV_DIR/bin/activate"
        python run.py "${SCRIPT_ARGS[@]}"
    else
        i "Run './go.sh' to start later"
    fi
}

trap 'echo ""; i "Interrupted."; exit 130' INT
main "$@"
