#!/usr/bin/env bash
set -u
set -o pipefail

REPO_URL="https://github.com/KianSantang777/MeduzaV3.git"
REPO_DIR="MeduzaV3"
BRANCH="main"
VENV_DIR="venv"

MAX_RETRIES=3
ERROR_LOG_LINES=25

RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
WHITE="\033[97m"

SPINNER_FRAMES=(
    "⠋"
    "⠙"
    "⠹"
    "⠸"
    "⠼"
    "⠴"
    "⠦"
    "⠧"
    "⠇"
    "⠏"
)

PLATFORM=""
DISTRO=""
PACKAGE_MANAGER=""
PYTHON_CMD=""
VENV_PYTHON=""
PRIVILEGE_CMD=()

CURRENT_TMP_DIR=""
SPINNER_PID=""

cleanup() {

    if [[ -n "${SPINNER_PID:-}" ]]; then

        if kill -0 "$SPINNER_PID" >/dev/null 2>&1; then
            kill "$SPINNER_PID" >/dev/null 2>&1 || true
        fi

        SPINNER_PID=""
    fi

    printf '\r\033[K'

    if [[ -n "${CURRENT_TMP_DIR:-}" &&
          -d "$CURRENT_TMP_DIR" ]]; then

        rm -rf "$CURRENT_TMP_DIR" >/dev/null 2>&1 || true
    fi
}

trap cleanup EXIT
trap 'printf "\n"; echo -e "${YELLOW}!${RESET} Installation interrupted."; exit 130' INT TERM


clear_screen() {
    if [[ -t 1 ]]; then
        clear 2>/dev/null || true
    fi
}

separator() {
    printf '%s\n' "────────────────────────────────────────────────────────────"
}

header() {

    clear_screen

    echo
    echo -e "${BOLD}${WHITE}MeduzaV3 Checker KianSantang${RESET}"
    echo -e "${DIM}Cross-Platform Environment Installer${RESET}"
    echo

    separator
    echo
}

section() {

    echo
    echo -e "${BOLD}${WHITE}$1${RESET}"
    separator
}

info() {
    echo -e "${CYAN}›${RESET} $1"
}

success() {
    echo -e "${GREEN}✓${RESET} $1"
}

warning() {
    echo -e "${YELLOW}!${RESET} $1"
}

failure() {
    echo -e "${RED}✗${RESET} $1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

spinner_loop() {

    local message="$1"
    local index=0

    while true; do

        printf '\r\033[K%s %s' \
            "${SPINNER_FRAMES[$index]}" \
            "$message"

        index=$((index + 1))

        if [[ "$index" -ge "${#SPINNER_FRAMES[@]}" ]]; then
            index=0
        fi

        sleep 0.10
    done
}

run_with_spinner() {

    local message="$1"
    shift

    local log_file
    local exit_code

    CURRENT_TMP_DIR="$(mktemp -d 2>/dev/null)"

    if [[ -z "$CURRENT_TMP_DIR" ||
          ! -d "$CURRENT_TMP_DIR" ]]; then

        failure "Unable to create temporary workspace."
        return 1
    fi

    log_file="$CURRENT_TMP_DIR/command.log"

    "$@" >"$log_file" 2>&1 &
    local command_pid=$!

    if [[ -t 1 ]]; then

        spinner_loop "$message" &
        SPINNER_PID=$!

    else
        info "$message"
    fi

    wait "$command_pid"
    exit_code=$?

    if [[ -n "${SPINNER_PID:-}" ]]; then

        if kill -0 "$SPINNER_PID" >/dev/null 2>&1; then
            kill "$SPINNER_PID" >/dev/null 2>&1 || true
        fi

        wait "$SPINNER_PID" 2>/dev/null || true
        SPINNER_PID=""
    fi

    printf '\r\033[K'

    if [[ "$exit_code" -eq 0 ]]; then

        success "$message"
        return 0
    fi

    failure "$message"

    if [[ -f "$log_file" ]]; then

        echo
        echo -e "${DIM}Last ${ERROR_LOG_LINES} lines of the error output:${RESET}"

        tail -n "$ERROR_LOG_LINES" "$log_file" 2>/dev/null || true

        echo
    fi

    return "$exit_code"
}


detect_platform() {

    if [[ -n "${TERMUX_VERSION:-}" ]] ||
       [[ -d "/data/data/com.termux" ]]; then

        PLATFORM="termux"

        if [[ -f "/etc/os-release" ]]; then
            DISTRO="$(grep '^ID=' /etc/os-release 2>/dev/null |
                cut -d= -f2 | tr -d '"')"
        else
            DISTRO="termux"
        fi

        return 0
    fi

    if [[ "$OSTYPE" == "darwin"* ]]; then

        PLATFORM="macos"
        DISTRO="macos"

        return 0
    fi

    if [[ "$OSTYPE" == "linux"* ]]; then

        PLATFORM="linux"

        if [[ -f "/etc/os-release" ]]; then

            DISTRO="$(
                grep '^ID=' /etc/os-release 2>/dev/null |
                cut -d= -f2 |
                tr -d '"' |
                tr '[:upper:]' '[:lower:]'
            )"

        else
            DISTRO="unknown"
        fi

        return 0
    fi

    PLATFORM="unknown"
    DISTRO="unknown"
}


detect_package_manager() {

    case "$PLATFORM" in

        termux)

            if command_exists pkg; then
                PACKAGE_MANAGER="pkg"
                return 0
            fi

            ;;

        macos)

            if command_exists brew; then
                PACKAGE_MANAGER="brew"
                return 0
            fi

            ;;

        linux)

            if command_exists apt-get; then
                PACKAGE_MANAGER="apt"
                return 0
            fi

            if command_exists dnf; then
                PACKAGE_MANAGER="dnf"
                return 0
            fi

            if command_exists yum; then
                PACKAGE_MANAGER="yum"
                return 0
            fi

            if command_exists pacman; then
                PACKAGE_MANAGER="pacman"
                return 0
            fi

            if command_exists apk; then
                PACKAGE_MANAGER="apk"
                return 0
            fi

            ;;

    esac

    PACKAGE_MANAGER="unknown"
}


setup_privilege_command() {

    PRIVILEGE_CMD=()

    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        return 0
    fi

    if command_exists sudo; then

        PRIVILEGE_CMD=("sudo")

        return 0
    fi

    failure "Root privileges or sudo are required."
    return 1
}


detect_python() {

    PYTHON_CMD=""

    if command_exists python3; then

        PYTHON_CMD="python3"
        return 0
    fi

    if command_exists python; then

        if python --version >/dev/null 2>&1; then

            PYTHON_CMD="python"
            return 0
        fi
    fi

    return 1
}


install_system_dependencies() {

    section "System environment"

    case "$PACKAGE_MANAGER" in

        pkg)

            info "Detected: Termux"

            run_with_spinner \
                "Updating package index" \
                pkg update -y \
                || return 1

            if ! command_exists git; then

                run_with_spinner \
                    "Installing Git" \
                    pkg install -y git \
                    || return 1

            else
                success "Git is already installed."
            fi

            if ! command_exists python; then

                run_with_spinner \
                    "Installing Python" \
                    pkg install -y python \
                    || return 1

            else
                success "Python is already installed."
            fi

            ;;

        apt)

            info "Detected: ${DISTRO:-Linux} / APT"

            setup_privilege_command || return 1

            if ! command_exists git ||
               ! command_exists python3; then

                run_with_spinner \
                    "Updating APT package index" \
                    "${PRIVILEGE_CMD[@]}" apt-get update -y \
                    || return 1

                run_with_spinner \
                    "Installing system dependencies" \
                    "${PRIVILEGE_CMD[@]}" apt-get install -y \
                    git \
                    python3 \
                    python3-pip \
                    python3-venv \
                    || return 1

            else
                success "Git and Python are already installed."
            fi

            ;;

        dnf)

            info "Detected: ${DISTRO:-Linux} / DNF"

            setup_privilege_command || return 1

            run_with_spinner \
                "Installing system dependencies" \
                "${PRIVILEGE_CMD[@]}" dnf install -y \
                git \
                python3 \
                python3-pip \
                || return 1

            ;;

        yum)

            info "Detected: ${DISTRO:-Linux} / YUM"

            setup_privilege_command || return 1

            run_with_spinner \
                "Installing system dependencies" \
                "${PRIVILEGE_CMD[@]}" yum install -y \
                git \
                python3 \
                python3-pip \
                || return 1

            ;;

        pacman)

            info "Detected: ${DISTRO:-Linux} / Pacman"

            setup_privilege_command || return 1

            run_with_spinner \
                "Synchronizing package database" \
                "${PRIVILEGE_CMD[@]}" pacman -Sy --noconfirm \
                || return 1

            run_with_spinner \
                "Installing system dependencies" \
                "${PRIVILEGE_CMD[@]}" pacman -S --noconfirm \
                git \
                python \
                python-pip \
                || return 1

            ;;

        apk)

            info "Detected: ${DISTRO:-Linux} / APK"

            setup_privilege_command || return 1

            run_with_spinner \
                "Installing system dependencies" \
                "${PRIVILEGE_CMD[@]}" apk add \
                git \
                python3 \
                py3-pip \
                || return 1

            ;;

        brew)

            info "Detected: macOS / Homebrew"

            if ! command_exists brew; then

                failure "Homebrew is not installed."
                echo
                echo "Install Homebrew first, then run this installer again."
                return 1
            fi

            if ! command_exists git; then

                run_with_spinner \
                    "Installing Git" \
                    brew install git \
                    || return 1

            else
                success "Git is already installed."
            fi

            if ! command_exists python3; then

                run_with_spinner \
                    "Installing Python" \
                    brew install python \
                    || return 1

            else
                success "Python is already installed."
            fi

            ;;

        *)

            failure "No supported package manager was detected."

            echo
            echo "Supported package managers:"
            echo "  apt"
            echo "  dnf"
            echo "  yum"
            echo "  pacman"
            echo "  apk"
            echo "  pkg"
            echo "  brew"
            echo

            return 1
            ;;

    esac

    hash -r 2>/dev/null || true

    if ! command_exists git; then

        failure "Git is still unavailable after installation."
        return 1
    fi

    if ! detect_python; then

        failure "Python is still unavailable after installation."
        return 1
    fi

    success "System environment is ready."
    return 0
}


repository_exists() {

    [[ -d "$REPO_DIR/.git" ]]
}

verify_git_repository() {

    if ! repository_exists; then
        return 0
    fi

    if ! git -C "$REPO_DIR" rev-parse --is-inside-work-tree \
        >/dev/null 2>&1; then

        failure "The existing repository is invalid."
        return 1
    fi

    return 0
}

repair_git_remote() {

    local current_remote

    current_remote="$(
        git -C "$REPO_DIR" remote get-url origin \
        2>/dev/null || true
    )"

    if [[ -z "$current_remote" ]]; then

        info "Git remote 'origin' is missing."

        git -C "$REPO_DIR" remote add origin "$REPO_URL" \
            || {
                failure "Unable to add Git remote."
                return 1
            }

        success "Git remote repaired."
        return 0
    fi

    if [[ "$current_remote" != "$REPO_URL" &&
          "$current_remote" != "${REPO_URL%.git}" ]]; then

        info "Git remote does not match the configured repository."
        info "Repairing remote configuration..."

        git -C "$REPO_DIR" remote set-url origin "$REPO_URL" \
            || {
                failure "Unable to repair Git remote."
                return 1
            }

        success "Git remote repaired."
    else
        success "Git remote is correct."
    fi

    return 0
}


setup_repository() {

    section "Repository"

    if ! repository_exists; then

        info "Repository is not installed."
        info "Cloning repository..."

        run_with_spinner \
            "Cloning MeduzaV3 repository" \
            git clone \
            --branch "$BRANCH" \
            --single-branch \
            "$REPO_URL" \
            "$REPO_DIR" \
            || return 1

        success "Repository cloned successfully."

        return 0
    fi

    verify_git_repository || return 1

    repair_git_remote || return 1

    info "Checking repository updates..."

    run_with_spinner \
        "Fetching repository metadata" \
        git -C "$REPO_DIR" fetch \
        --prune \
        origin \
        "$BRANCH" \
        || return 1

    local current_branch

    current_branch="$(
        git -C "$REPO_DIR" branch \
        --show-current 2>/dev/null || true
    )"

    if [[ "$current_branch" != "$BRANCH" ]]; then

        info "Switching to branch '${BRANCH}'..."

        if git -C "$REPO_DIR" show-ref \
            --verify \
            --quiet \
            "refs/heads/$BRANCH"; then

            git -C "$REPO_DIR" checkout "$BRANCH" \
                >/dev/null 2>&1 \
                || {
                    failure "Unable to switch to branch '${BRANCH}'."
                    return 1
                }

        else

            git -C "$REPO_DIR" checkout \
                -b "$BRANCH" \
                "origin/$BRANCH" \
                >/dev/null 2>&1 \
                || {
                    failure "Unable to create local branch '${BRANCH}'."
                    return 1
                }
        fi

        success "Using branch '${BRANCH}'."
    fi

    local local_commit
    local remote_commit

    local_commit="$(
        git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null || true
    )"

    remote_commit="$(
        git -C "$REPO_DIR" rev-parse \
            "origin/$BRANCH" 2>/dev/null || true
    )"

    if [[ -z "$local_commit" ||
          -z "$remote_commit" ]]; then

        failure "Unable to compare local and remote commits."
        return 1
    fi

    if [[ "$local_commit" == "$remote_commit" ]]; then

        success "Repository is already up to date."
        return 0
    fi

    info "A repository update is available."
    info "Applying update..."

    if run_with_spinner \
        "Updating repository" \
        git -C "$REPO_DIR" pull \
        --rebase \
        --autostash \
        origin \
        "$BRANCH"; then

        success "Repository updated successfully."
        return 0
    fi

    echo
    warning "Automatic repository update failed."
    warning "This is usually caused by an unresolvable local Git conflict."

    echo
    echo -e "${DIM}Repository status:${RESET}"

    git -C "$REPO_DIR" status --short 2>/dev/null || true

    return 1
}


venv_is_healthy() {

    [[ -x "$VENV_DIR/bin/python" ]] || return 1

    "$VENV_DIR/bin/python" --version >/dev/null 2>&1 || return 1

    "$VENV_DIR/bin/python" -m pip --version \
        >/dev/null 2>&1 || return 1

    return 0
}

repair_venv_dependencies() {

    if [[ "$PACKAGE_MANAGER" != "apt" ]]; then
        return 1
    fi

    setup_privilege_command || return 1

    info "Repairing Python virtual-environment support..."

    run_with_spinner \
        "Installing python3-venv" \
        "${PRIVILEGE_CMD[@]}" apt-get install -y \
        python3-venv \
        || return 1

    return 0
}

create_virtual_environment() {

    if "$PYTHON_CMD" -m venv "$VENV_DIR" \
        >/dev/null 2>&1; then

        return 0
    fi

    warning "Virtual environment creation failed."

    if repair_venv_dependencies; then

        run_with_spinner \
            "Recreating Python virtual environment" \
            "$PYTHON_CMD" -m venv "$VENV_DIR" \
            || return 1

        return 0
    fi

    return 1
}

setup_virtual_environment() {

    section "Python environment"

    detect_python || {
        failure "Python could not be detected."
        return 1
    }

    info "Using Python: $PYTHON_CMD"

    if [[ -d "$VENV_DIR" ]] &&
       ! venv_is_healthy; then

        warning "Existing virtual environment is unhealthy."
        info "Removing corrupted virtual environment..."

        rm -rf "$VENV_DIR" || {

            failure "Unable to remove corrupted virtual environment."
            return 1
        }

        success "Corrupted virtual environment removed."
    fi

    if ! venv_is_healthy; then

        run_with_spinner \
            "Creating Python virtual environment" \
            create_virtual_environment \
            || {

                failure "Unable to create Python virtual environment."
                return 1
            }

        success "Virtual environment created."
    else

        success "Virtual environment is healthy."
    fi

    VENV_PYTHON="$VENV_DIR/bin/python"

    if ! "$VENV_PYTHON" -m pip --version \
        >/dev/null 2>&1; then

        warning "pip is missing from the virtual environment."

        if [[ "$PACKAGE_MANAGER" == "apt" ]]; then

            repair_venv_dependencies || {
                failure "Unable to repair pip support."
                return 1
            }
        fi

        rm -rf "$VENV_DIR" || {
            failure "Unable to rebuild the virtual environment."
            return 1
        }

        run_with_spinner \
            "Rebuilding Python virtual environment" \
            create_virtual_environment \
            || {

                failure "Virtual environment rebuild failed."
                return 1
            }

        VENV_PYTHON="$VENV_DIR/bin/python"
    fi

    if ! "$VENV_PYTHON" -m pip --version \
        >/dev/null 2>&1; then

        failure "pip is still unavailable."
        return 1
    fi

    run_with_spinner \
        "Upgrading pip, setuptools and wheel" \
        "$VENV_PYTHON" -m pip install \
        --upgrade \
        pip \
        setuptools \
        wheel \
        || return 1

    success "Python environment is ready."

    return 0
}


install_requirements() {

    section "Python dependencies"

    if [[ ! -f "requirements.txt" ]]; then

        warning "requirements.txt was not found."
        warning "Dependency installation was skipped."

        return 0
    fi

    local attempt=1

    while [[ "$attempt" -le "$MAX_RETRIES" ]]; do

        if run_with_spinner \
            "Installing requirements.txt (attempt ${attempt}/${MAX_RETRIES})" \
            "$VENV_PYTHON" -m pip install \
            --upgrade \
            -r requirements.txt; then

            success "requirements.txt installed successfully."
            break
        fi

        if [[ "$attempt" -ge "$MAX_RETRIES" ]]; then

            failure "Failed to install requirements.txt after ${MAX_RETRIES} attempts."
            return 1
        fi

        warning "Dependency installation failed."
        info "Retrying in 2 seconds..."

        sleep 2

        attempt=$((attempt + 1))
    done

    run_with_spinner \
        "Checking installed Python dependencies" \
        "$VENV_PYTHON" -m pip check \
        || {

            warning "pip check detected dependency issues."
            info "Attempting automatic dependency repair..."

            run_with_spinner \
                "Reinstalling requirements.txt" \
                "$VENV_PYTHON" -m pip install \
                --upgrade \
                --force-reinstall \
                -r requirements.txt \
                || {

                    failure "Automatic dependency repair failed."
                    return 1
                }

            run_with_spinner \
                "Running dependency verification again" \
                "$VENV_PYTHON" -m pip check \
                || {

                    failure "Dependency verification still fails."
                    return 1
                }
        }

    success "All Python dependencies are consistent."
}


final_validation() {

    section "Final validation"

    local failed=0

    if command_exists git; then
        success "Git"
    else
        failure "Git"
        failed=1
    fi

    if detect_python; then
        success "Python: $PYTHON_CMD"
    else
        failure "Python"
        failed=1
    fi

    if [[ -x "$VENV_DIR/bin/python" ]]; then
        success "Virtual environment"
    else
        failure "Virtual environment"
        failed=1
    fi

    if [[ -x "$VENV_PYTHON" ]] &&
       "$VENV_PYTHON" -m pip --version \
       >/dev/null 2>&1; then

        success "pip"
    else
        failure "pip"
        failed=1
    fi

    if [[ -f "requirements.txt" ]]; then
        success "requirements.txt"
    else
        warning "requirements.txt not found"
    fi

    if [[ "$failed" -ne 0 ]]; then
        return 1
    fi

    return 0
}


show_summary() {

    section "Installation complete"

    echo -e "${GREEN}✓${RESET} Platform        : ${PLATFORM}"
    echo -e "${GREEN}✓${RESET} Distribution    : ${DISTRO}"
    echo -e "${GREEN}✓${RESET} Package manager : ${PACKAGE_MANAGER}"
    echo -e "${GREEN}✓${RESET} Repository      : ${REPO_DIR}"
    echo -e "${GREEN}✓${RESET} Branch          : ${BRANCH}"
    echo -e "${GREEN}✓${RESET} Python          : ${PYTHON_CMD}"
    echo -e "${GREEN}✓${RESET} Virtual env     : ${VENV_DIR}"
    echo -e "${GREEN}✓${RESET} Dependencies    : installed"

    echo
    separator
    echo
    echo -e "${BOLD}${WHITE}Environment is ready.${RESET}"
    echo
    echo -e "${DIM}Activate the environment with:${RESET}"
    echo
    echo -e "  ${WHITE}cd ${REPO_DIR}${RESET}"
    echo -e "  ${WHITE}source ${VENV_DIR}/bin/activate${RESET}"
    echo
    echo -e "${DIM}This installer does not start run.py.${RESET}"
    echo
}


main() {

    header

    detect_platform
    detect_package_manager

    info "Platform        : ${PLATFORM}"
    info "Distribution    : ${DISTRO}"
    info "Package manager : ${PACKAGE_MANAGER}"

    if [[ "$PLATFORM" == "unknown" ]]; then

        failure "Unsupported operating system."
        exit 1
    fi

    if [[ "$PACKAGE_MANAGER" == "unknown" ]]; then

        failure "Unsupported or undetected package manager."
        exit 1
    fi

    install_system_dependencies || {
        failure "System dependency setup failed."
        exit 1
    }

    setup_repository || {
        failure "Repository setup failed."
        exit 1
    }

    cd "$REPO_DIR" || {
        failure "Unable to enter repository directory."
        exit 1
    }

    setup_virtual_environment || {
        failure "Python environment setup failed."
        exit 1
    }

    install_requirements || {
        failure "Python dependency setup failed."
        exit 1
    }

    final_validation || {
        failure "Final validation failed."
        exit 1
    }

    show_summary
}

main "$@"
