#!/usr/bin/env bash
set -Eeo pipefail

trap '_fatal_handler' ERR
trap '_interrupt_handler' INT
trap '_exit_handler' EXIT

VENV_DIR="${VENV_DIR:-venv}"
BRANCH="${BRANCH:-main}"
PYTHON_MIN_VERSION="3.8"

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

FAILED_STEPS=()
WARNINGS=()
EXIT_CODE=0
AUTO_YES=1

_os_type=""
_os_arch=""

_log() {
    local level="$1"
    shift
    local msg="$*"
    local ts
    ts=$(date '+%H:%M:%S' 2>/dev/null || echo "??:??")

    case "$level" in
        step)  printf '%s%s[%s]%s %s\n' "$CYAN" "$ARROW" "$ts" "$RESET" "$msg" ;;
        ok)    printf '%s%s[%s]%s %s\n' "$GREEN" "$CHECK" "$ts" "$RESET" "$msg" ;;
        fail)  printf '%s%s[%s]%s %s\n' "$RED" "$CROSS" "$ts" "$RESET" "$msg" >&2; EXIT_CODE=1 ;;
        warn)  printf '%s%s[%s]%s %s\n' "$YELLOW" "$WARN" "$ts" "$RESET" "$msg"; WARNINGS+=("$msg") ;;
        debug) [[ "${DEBUG:-0}" == "1" ]] && printf '%s[%s] DEBUG: %s\n' "$MAGENTA" "$ts" "$msg" ;;
    esac
}

i()  { _log step "$*"; }
s()  { _log ok "$*"; }
e()  { _log fail "$*"; }
w()  { _log warn "$*"; }
d()  { _log debug "$*"; }

_fatal_handler() {
    local line="${BASH_LINENO[0]}"
    local code=$?
    _log fail "Error at line $line (exit: $code)"
    if [[ ${#FAILED_STEPS[@]} -gt 0 ]]; then
        echo ""
        _log warn "Failed steps:"
        for step in "${FAILED_STEPS[@]}"; do echo "    - $step"; done
    fi
    exit $code
}

_interrupt_handler() {
    echo ""
    _log warn "Interrupted"
    exit 130
}

_exit_handler() {
    [[ ${#WARNINGS[@]} -gt 0 ]] && _log warn "Completed with ${#WARNINGS[@]} warning(s)"
}

detect_os() {
    if [[ -n "$_os_type" ]]; then echo "$_os_type"; return; fi

    if [[ -n "${TERMUX_VERSION:-}" ]] || [[ -d "/data/data/com.termux" ]]; then
        _os_type="termux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        _os_type="macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
        if [[ -f /etc/os-release ]]; then
            local id
            id=$(grep -oP '^ID=\K\w+' /etc/os-release 2>/dev/null || echo "")
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
    if [[ -n "$_os_arch" ]]; then echo "$_os_arch"; return; fi
    local arch
    arch=$(uname -m 2>/dev/null || echo "unknown")
    case "$arch" in
        x86_64|amd64) _os_arch="x64" ;;
        aarch64|arm64) _os_arch="arm64" ;;
        armv7l|armhf) _os_arch="arm" ;;
        i386|i686) _os_arch="x86" ;;
        *) _os_arch="$arch" ;;
    esac
    echo "$_os_arch"
}

check_cmd() {
    command -v "$1" >/dev/null 2>&1
}

check_python() {
    local -a versions=("python3" "python" "python3.12" "python3.11" "python3.10" "python3.9" "python3.8")
    for py in "${versions[@]}"; do
        if check_cmd "$py"; then
            local bin ver
            bin=$(command -v "$py")
            ver=$("$py" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || echo "")
            if [[ -n "$ver" ]]; then
                PYTHON_BIN="$bin"
                PYTHON_VERSION="$ver"
                local major minor
                major=$(echo "$ver" | cut -d. -f1)
                minor=$(echo "$ver" | cut -d. -f2)
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
        macos)   check_cmd brew && brew install git ;;
        windows) w "Install git from https://git-scm.com"; return 1 ;;
        *)       w "Unsupported OS"; return 1 ;;
    esac
    if check_cmd git; then
        s "Git installed"
    else
        e "Git installation failed"
        return 1
    fi
}

install_python() {
    i "Installing Python..."
    case "$(detect_os)" in
        termux)  pkg update -y >/dev/null 2>&1 && pkg install -y python python-pip ;;
        debian)  sudo apt-get update -y >/dev/null 2>&1 && sudo apt-get install -y python3 python3-pip python3-venv ;;
        redhat)  sudo dnf install -y python3 python3-pip >/dev/null 2>&1 || sudo yum install -y python3 python3-pip ;;
        arch)    sudo pacman -Syu --noconfirm python python-pip ;;
        alpine)  apk add --no-cache python3 py3-pip ;;
        macos)   check_cmd brew && brew install python ;;
        windows) e "Install Python from python.org"; return 1 ;;
        *)       e "Unsupported OS"; return 1 ;;
    esac
    hash -r 2>/dev/null || true
    if check_python; then
        s "Python installed: $PYTHON_VERSION"
    else
        e "Python installation failed"
        return 1
    fi
}

install_pip() {
    i "Installing pip..."
    if "${PYTHON_BIN}" -m ensurepip --upgrade >/dev/null 2>&1; then
        s "pip installed"
        return 0
    fi
    if check_cmd curl; then
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
    if ! "${PYTHON_BIN}" -m venv "$VENV_DIR"; then
        e "Failed to create venv"
        return 1
    fi
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
    local -a packages=(
        "requests" "colorama" "tqdm" "faker"
        "requests-toolbelt" "cython" "pyfiglet" "python-socketio"
    )

    i "Installing packages..."

    python -m pip install --upgrade pip -q 2>/dev/null

    local failed=0
    local total=${#packages[@]}
    local cur=0

    for pkg in "${packages[@]}"; do
        ((cur++))
        printf '\r  %s[%d/%d]%s %-20s ' "$CYAN" "$cur" "$total" "$RESET" "$pkg"
        if python -m pip install --no-cache-dir "$pkg" -q 2>/dev/null; then
            printf '%s✓%s\n' "$GREEN" "$RESET"
        else
            printf '%s✗%s\n' "$RED" "$RESET"
            ((failed++))
            WARNINGS+=("Failed: $pkg")
        fi
    done

    echo ""
    if [[ $failed -gt 0 ]]; then
        w "$failed/$total package(s) failed"
        return 1
    fi
    s "Packages installed"
}

check_updates() {
    check_cmd git || return 0
    [[ -d ".git" ]] || return 0
    git remote get-url origin >/dev/null 2>&1 || return 0

    i "Checking updates..."
    git fetch origin "$BRANCH" --quiet 2>/dev/null || { w "Fetch failed"; return 0; }

    local local_rev remote_rev
    local_rev=$(git rev-parse HEAD 2>/dev/null || echo "")
    remote_rev=$(git rev-parse "origin/$BRANCH" 2>/dev/null || echo "")

    [[ -z "$local_rev" || -z "$remote_rev" ]] && return 0

    if [[ "$local_rev" != "$remote_rev" ]]; then
        echo ""
        echo -e "  ${YELLOW}┌─────────────────────────────────────┐${RESET}"
        echo -e "  ${YELLOW}│${RESET}         ${BOLD}UPDATE AVAILABLE${RESET}             ${YELLOW}│${RESET}"
        echo -e "  ${YELLOW}└─────────────────────────────────────┘${RESET}"
        echo ""
        echo -n "  Update now? [Y/n]: "
        read -n 1 -r REPLY
        echo ""
        if [[ ! "$REPLY" =~ ^[Nn]$ ]]; then
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
    local missing=0

    if [[ -f "run.py" ]]; then
        s "run.py found"
    else
        e "Missing: run.py"
        ((missing++))
    fi

    local binary
    if [[ "$(detect_os)" == "windows" ]]; then
        binary=$(find . -maxdepth 1 -name "*.pyd" 2>/dev/null | head -n1)
    else
        binary=$(find . -maxdepth 1 \( -name "*.so" -o -name "*.pyd" \) 2>/dev/null | head -n1)
    fi

    if [[ -n "$binary" ]]; then
        s "Binary: $(basename "$binary")"
    else
        w "No binary found"
        if [[ -f "build.py" ]]; then
            echo -n "  Build now? [Y/n]: "
            read -n 1 -r REPLY
            echo ""
            if [[ ! "$REPLY" =~ ^[Nn]$ ]]; then
                i "Building..."
                python build.py >/dev/null 2>&1 && s "Build complete" || w "Build failed"
            fi
        fi
    fi

    return $missing
}

main() {
    SCRIPT_ARGS=("$@")

    for arg in "$@"; do
        case "$arg" in
            --debug) DEBUG=1 ;;
            --dry-run) DRY_RUN=1 ;;
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
        install_python || exit 1
    fi
    s "Python: ${PYTHON_VERSION}"

    if ! check_cmd git; then
        install_git || w "Git skipped"
    fi

    if ! check_pip; then
        install_pip || exit 1
    fi

    if [[ ! -d "$VENV_DIR" ]]; then
        setup_venv || exit 1
    fi

    activate_venv || exit 1
    install_packages
    check_updates
    check_files

    echo ""
    echo -e "  ${GREEN}╔═══════════════════════════════════════════╗${RESET}"
    echo -e "  ${GREEN}║${RESET}         ${BOLD}Ready to start!${RESET}                 ${GREEN}║${RESET}"
    echo -e "  ${GREEN}╚═══════════════════════════════════════════╝${RESET}"
    echo ""

    i "Starting MeduzaV3..."
    echo ""
    python run.py "${SCRIPT_ARGS[@]}"
    EXIT_CODE=$?

    [[ $EXIT_CODE -eq 0 ]] && s "Completed" || w "Exit code: $EXIT_CODE"
    exit $EXIT_CODE
}

main "$@"
