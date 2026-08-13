#!/usr/bin/env bash

VENV_DIR="${VENV_DIR:-venv}"
BRANCH="${BRANCH:-main}"

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
MAGENTA=$'\033[0;35m'
WHITE=$'\033[1;37m'
RESET=$'\033[0m'
BOLD=$'\033[1m'

CHECK="${GREEN}✓${RESET}"
CROSS="${RED}✗${RESET}"
ARROW="${CYAN}▸${RESET}"
WARN="${YELLOW}⚠${RESET}"

WARNINGS=""
EXIT_CODE=0

_os_type=""
_os_arch=""
PYTHON_BIN=""
PYTHON_VERSION=""
PYTHON_CMD=""

_log() {
    local level="$1"
    shift
    local msg="$*"
    local ts
    ts=$(date '+%H:%M:%S' 2>/dev/null)

    case "$level" in
        step)  printf '%s%s[%s]%s %s\n' "$CYAN" "$ARROW" "$ts" "$RESET" "$msg" ;;
        ok)    printf '%s%s[%s]%s %s\n' "$GREEN" "$CHECK" "$ts" "$RESET" "$msg" ;;
        fail)  printf '%s%s[%s]%s %s\n' "$RED" "$CROSS" "$ts" "$RESET" "$msg" >&2; EXIT_CODE=1 ;;
        warn)  printf '%s%s[%s]%s %s\n' "$YELLOW" "$WARN" "$ts" "$RESET" "$msg"; WARNINGS="${WARNINGS}|${msg}" ;;
        debug) [[ "${DEBUG:-0}" == "1" ]] && printf '%s[%s] DEBUG: %s\n' "$MAGENTA" "$ts" "$msg" ;;
    esac
}

i() { _log step "$*"; }
s() { _log ok "$*"; }
e() { _log fail "$*"; }
w() { _log warn "$*"; }
d() { _log debug "$*"; }

trap 'echo ""; _log warn "Interrupted"; exit 130' INT

detect_os() {
    [[ -n "$_os_type" ]] && { echo "$_os_type"; return; }

    if [[ -n "${TERMUX_VERSION:-}" ]] || [[ -d "/data/data/com.termux" ]]; then
        _os_type="termux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        _os_type="macos"
    elif [[ "$OSTYPE" == "linux"* ]]; then
        if [[ -f /etc/os-release ]]; then
            local id
            id=$(grep -oP '^ID=\K\w+' /etc/os-release 2>/dev/null)
            case "$id" in
                ubuntu|debian|kali|linuxmint|pop|elementary) _os_type="debian" ;;
                fedora|rhel|centos|rocky|alma) _os_type="redhat" ;;
                arch|manjaro|endeavouros) _os_type="arch" ;;
                alpine) _os_type="alpine" ;;
                *) _os_type="linux" ;;
            esac
        elif [[ -f /etc/redhat-release ]]; then
            _os_type="redhat"
        elif [[ -f /etc/debian_version ]]; then
            _os_type="debian"
        else
            _os_type="linux"
        fi
    elif [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "cygwin"* ]]; then
        _os_type="windows"
    else
        _os_type="unknown"
    fi

    echo "$_os_type"
}

detect_arch() {
    [[ -n "$_os_arch" ]] && { echo "$_os_arch"; return; }
    local arch
    arch=$(uname -m 2>/dev/null)
    case "$arch" in
        x86_64|amd64) _os_arch="x64" ;;
        aarch64|arm64) _os_arch="arm64" ;;
        armv7l|armhf) _os_arch="arm" ;;
        i386|i686) _os_arch="x86" ;;
        *) _os_arch="$arch" ;;
    esac
    echo "$_os_arch"
}

has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

check_python() {
    local versions="python3 python python3.12 python3.11 python3.10 python3.9 python3.8"
    for py in $versions; do
        if has_cmd "$py"; then
            local bin ver
            bin=$(command -v "$py")
            ver=$("$py" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null)
            if [[ -n "$ver" ]]; then
                PYTHON_BIN="$bin"
                PYTHON_VERSION="$ver"
                local major minor
                major=${ver%%.*}
                minor=${ver#*.}
                minor=${minor%%.*}
                if [[ "$major" -lt 3 ]] || { [[ "$major" -eq 3 ]] && [[ "$minor" -lt 8 ]]; }; then
                    w "Python $ver detected (needs 3.8+)"
                    continue
                fi
                d "Python: $PYTHON_BIN ($PYTHON_VERSION)"
                return 0
            fi
        fi
    done
    return 1
}

check_pip() {
    [[ -z "${PYTHON_BIN:-}" ]] && return 1
    "${PYTHON_BIN}" -m pip --version >/dev/null 2>&1
}

install_git() {
    i "Installing git..."
    case "$(detect_os)" in
        termux)  pkg update -y >/dev/null 2>&1 && pkg install -y git ;;
        debian)  sudo apt-get update -y >/dev/null 2>&1 && sudo apt-get install -y git ;;
        redhat)  sudo dnf install -y git >/dev/null 2>&1 || sudo yum install -y git ;;
        arch)    sudo pacman -Syu --noconfirm git ;;
        alpine)  apk add --no-cache git ;;
        macos)   has_cmd brew && brew install git ;;
        windows) w "Install git from https://git-scm.com"; return 1 ;;
        *)       w "Unsupported OS"; return 1 ;;
    esac
    has_cmd git && s "Git installed" || { e "Git installation failed"; return 1; }
}

install_python() {
    i "Installing Python..."
    case "$(detect_os)" in
        termux)  pkg update -y >/dev/null 2>&1 && pkg install -y python python-pip ;;
        debian)  sudo apt-get update -y >/dev/null 2>&1 && sudo apt-get install -y python3 python3-pip python3-venv ;;
        redhat)  sudo dnf install -y python3 python3-pip >/dev/null 2>&1 || sudo yum install -y python3 python3-pip ;;
        arch)    sudo pacman -Syu --noconfirm python python-pip ;;
        alpine)  apk add --no-cache python3 py3-pip ;;
        macos)   has_cmd brew && brew install python ;;
        windows) e "Install Python from python.org"; return 1 ;;
        *)       e "Unsupported OS"; return 1 ;;
    esac
    hash -r 2>/dev/null
    check_python && s "Python installed: $PYTHON_VERSION" || { e "Python installation failed"; return 1; }
}

install_pip() {
    i "Installing pip..."
    if "${PYTHON_BIN}" -m ensurepip --upgrade >/dev/null 2>&1; then
        s "pip installed"
        return 0
    fi
    if has_cmd curl; then
        curl -sS https://bootstrap.pypa.io/get-pip.py | "${PYTHON_BIN}" >/dev/null 2>&1 && {
            s "pip installed"
            return 0
        }
    fi
    e "pip installation failed"
    return 1
}

setup_venv() {
    i "Setting up venv..."
    [[ -d "$VENV_DIR" ]] && rm -rf "$VENV_DIR"
    "${PYTHON_BIN}" -m venv "$VENV_DIR" || { e "Failed to create venv"; return 1; }
    s "Venv ready: $VENV_DIR"
}

activate_venv() {
    if [[ -f "${VENV_DIR}/bin/activate" ]]; then
        source "${VENV_DIR}/bin/activate"
    elif [[ -f "${VENV_DIR}/Scripts/activate" ]]; then
        source "${VENV_DIR}/Scripts/activate"
    else
        e "Venv activation failed"
        return 1
    fi
    d "Venv activated"
}

install_packages() {
    i "Installing packages..."

    python -m pip install --upgrade pip -q 2>/dev/null

    local packages="requests colorama tqdm faker requests-toolbelt cython pyfiglet python-socketio"
    local total=8
    local cur=0

    for pkg in $packages; do
        cur=$((cur + 1))
        printf '\r  %s[%d/%d]%s %-20s ' "$CYAN" "$cur" "$total" "$RESET" "$pkg"
        if python -m pip install --no-cache-dir "$pkg" -q 2>/dev/null; then
            printf '%s✓%s\n' "$GREEN" "$RESET"
        else
            printf '%s✗%s\n' "$RED" "$RESET"
            w "Failed: $pkg"
        fi
    done

    echo ""
    s "Packages installed"
}

check_updates() {
    has_cmd git || return 0
    [[ -d ".git" ]] || return 0
    git remote get-url origin >/dev/null 2>&1 || return 0

    i "Checking updates..."
    git fetch origin "$BRANCH" --quiet 2>/dev/null || { w "Fetch failed"; return 0; }

    local local_rev=$(git rev-parse HEAD 2>/dev/null)
    local remote_rev=$(git rev-parse "origin/$BRANCH" 2>/dev/null)

    [[ -z "$local_rev" || -z "$remote_rev" ]] && return 0

    if [[ "$local_rev" != "$remote_rev" ]]; then
        echo ""
        echo -e "  ${YELLOW}┌─────────────────────────────────────┐${RESET}"
        echo -e "  ${YELLOW}│${RESET}         ${BOLD}UPDATE AVAILABLE${RESET}             ${YELLOW}│${RESET}"
        echo -e "  ${YELLOW}└─────────────────────────────────────┘${RESET}"
        echo -n "  Update now? [Y/n]: "
        read -n 1 -r REPLY
        echo ""
        if [[ ! "$REPLY" =~ ^[Nn]$ ]]; then
            i "Updating..."
            if git pull origin "$BRANCH" --autostash 2>/dev/null; then
                s "Updated!"
                exec "$0" "$@"
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
    [[ -f "run.py" ]] && s "run.py found" || { e "Missing: run.py"; return 1; }

    local binary=""
    if [[ "$(detect_os)" == "windows" ]]; then
        binary=$(find . -maxdepth 1 -name "*.pyd" 2>/dev/null | head -n1)
    else
        binary=$(find . -maxdepth 1 \( -name "*.so" -o -name "*.pyd" \) 2>/dev/null | head -n1)
    fi

    [[ -n "$binary" ]] && s "Binary: $(basename "$binary")" || w "No binary found"

    [[ -f "build.py" && -z "$binary" ]] && {
        echo -n "  Build now? [Y/n]: "
        read -n 1 -r REPLY
        echo ""
        if [[ ! "$REPLY" =~ ^[Nn]$ ]]; then
            i "Building..."
            python build.py >/dev/null 2>&1 && s "Build complete" || w "Build failed"
        fi
    }

    return 0
}

get_python_cmd() {
    local os
    os=$(detect_os)
    case "$os" in
        termux)
            PYTHON_CMD="python run.py"
            ;;
        macos)
            PYTHON_CMD="python3 run.py"
            ;;
        debian|redhat|arch|alpine|linux)
            PYTHON_CMD="python3 run.py"
            ;;
        windows)
            PYTHON_CMD="python run.py"
            ;;
        *)
            PYTHON_CMD="python run.py"
            ;;
    esac
    echo "$PYTHON_CMD"
}

run_app() {
    local cmd
    cmd=$(get_python_cmd)

    echo ""
    echo -e "  ${GREEN}╔═══════════════════════════════════════════╗${RESET}"
    echo -e "  ${GREEN}║${RESET}         ${BOLD}Ready to start!${RESET}                 ${GREEN}║${RESET}"
    echo -e "  ${GREEN}╚═══════════════════════════════════════════╝${RESET}"
    echo ""

    i "Starting MeduzaV3..."
    i "Command: $cmd"
    echo ""

    eval "$cmd"
    EXIT_CODE=$?

    echo ""
    [[ $EXIT_CODE -eq 0 ]] && s "Completed successfully" || w "Exit code: $EXIT_CODE"
    exit $EXIT_CODE
}

main() {
    for arg in "$@"; do
        case "$arg" in
            --debug) DEBUG=1 ;;
        esac
    done

    echo ""
    echo -e "  ${MAGENTA}╔═══════════════════════════════════════════╗${RESET}"
    echo -e "  ${MAGENTA}║${RESET}              ${BOLD}${WHITE}MeduzaV3${RESET}                    ${MAGENTA}║${RESET}"
    echo -e "  ${MAGENTA}║${RESET}           ${CYAN}Tools CC Checker${RESET}                ${MAGENTA}║${RESET}"
    echo -e "  ${MAGENTA}║${RESET}        t.me/xqndrs │ t.me/xqndrs66       ${MAGENTA}║${RESET}"
    echo -e "  ${MAGENTA}╚═══════════════════════════════════════════╝${RESET}"
    echo ""

    local os
    os=$(detect_os)
    echo -e "  ${CYAN}OS:${RESET}       $os ($(detect_arch))"
    echo -e "  ${CYAN}Python:${RESET}   ${PYTHON_VERSION:-not found}"
    echo -e "  ${CYAN}Venv:${RESET}     ${VENV_DIR}"
    echo ""

    if ! check_python; then
        if ! install_python; then
            e "Python installation failed"
            exit 1
        fi
    fi
    s "Python: ${PYTHON_VERSION}"

    if ! has_cmd git; then
        install_git || w "Git installation skipped"
    fi

    if ! check_pip; then
        if ! install_pip; then
            e "pip installation failed"
            exit 1
        fi
    fi

    if [[ ! -d "$VENV_DIR" ]]; then
        setup_venv || exit 1
    else
        s "Venv exists: $VENV_DIR"
    fi

    activate_venv || exit 1
    install_packages
    check_updates "$@"
    check_files || exit 1

    run_app "$@"
}

main "$@"
