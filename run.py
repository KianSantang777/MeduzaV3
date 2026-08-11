#!/usr/bin/env python3
import importlib.machinery
import importlib.util
import os
import platform
import sys
from pathlib import Path
MODULE_NAME = "protected_card"
REQUIRED_PYTHON = (3, 13, 3)
class Colors:
    RESET = "\033[0m"
    BOLD = "\033[1m"
    DIM = "\033[2m"
    RED = "\033[31m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    BLUE = "\033[34m"
    CYAN = "\033[36m"
    WHITE = "\033[37m"
def enable_colors():
    if os.name == "nt":
        try:
            import ctypes
            kernel32 = ctypes.windll.kernel32
            handle = kernel32.GetStdHandle(-11)
            mode = ctypes.c_ulong()
            if kernel32.GetConsoleMode(
                handle,
                ctypes.byref(mode),
            ):
                kernel32.SetConsoleMode(
                    handle,
                    mode.value | 0x0004,
                )
        except (AttributeError, OSError):
            return False
    return True
COLORS_ENABLED = enable_colors()
def color(text, code):
    if not COLORS_ENABLED:
        return text
    return f"{code}{text}{Colors.RESET}"
def title(text):
    return color(text, Colors.BOLD + Colors.CYAN)
def info(text):
    return color("[INFO]", Colors.CYAN) + f" {text}"
def success(text):
    return color("[OK]", Colors.GREEN) + f" {text}"
def warning(text):
    return color("[WARN]", Colors.YELLOW) + f" {text}"
def error(text):
    return color("[ERROR]", Colors.RED) + f" {text}"
def fatal(text):
    return color("[FATAL]", Colors.BOLD + Colors.RED) + f" {text}"
def is_termux():
    prefix = os.environ.get("PREFIX", "")
    return (
        "TERMUX_VERSION" in os.environ
        or prefix.startswith("/data/data/com.termux")
    )
def get_platform_name():
    if is_termux():
        return "Android (Termux)"
    system = platform.system().lower()
    if system == "windows":
        return "Windows"
    if system == "darwin":
        return "macOS"
    if system == "linux":
        return "Linux"
    return platform.system()
def get_binary_extensions():
    if is_termux():
        return (".so",)
    system = platform.system().lower()
    if system == "windows":
        return (".pyd",)
    if system in ("linux", "darwin"):
        return (".so",)
    return (".pyd", ".so")
def check_python_version():
    current = sys.version_info[:3]
    if current != REQUIRED_PYTHON:
        current_version = ".".join(map(str, current))
        required_version = ".".join(
            map(str, REQUIRED_PYTHON)
        )
        print(
            error(
                f"Python {current_version} detected. "
                f"Required: Python {required_version}."
            )
        )
        return False
    return True
def get_expected_suffixes():
    if is_termux():
        return (".so",)
    system = platform.system().lower()
    suffixes = importlib.machinery.EXTENSION_SUFFIXES
    if system == "windows":
        return tuple(
            suffix.lower()
            for suffix in suffixes
            if suffix.lower().endswith(".pyd")
            and "cp313" in suffix.lower()
        )
    return tuple(
        suffix.lower()
        for suffix in suffixes
        if "cp313" in suffix.lower()
    )
def is_valid_file(path):
    try:
        return (
            path.is_file()
            and path.stat().st_size > 0
            and os.access(path, os.R_OK)
        )
    except OSError:
        return False
def find_binary(directory):
    extensions = get_binary_extensions()
    suffixes = get_expected_suffixes()
    try:
        files = []
        for path in directory.iterdir():
            if not is_valid_file(path):
                continue
            if not path.name.startswith(MODULE_NAME):
                continue
            name = path.name.lower()
            if not any(
                name.endswith(extension)
                for extension in extensions
            ):
                continue
            files.append(path)
        if not files:
            return None
        exact_names = {
            f"{MODULE_NAME}{extension}"
            for extension in extensions
        }
        for path in files:
            if path.name.lower() in exact_names:
                return path
        for path in files:
            name = path.name.lower()
            if any(
                name.endswith(suffix)
                for suffix in suffixes
            ):
                return path
        if is_termux():
            return files[0]
        return None
    except OSError as exc:
        print(error(f"Unable to scan directory: {exc}"))
        return None
def load_binary(binary_path):
    try:
        spec = importlib.util.spec_from_file_location(
            MODULE_NAME,
            str(binary_path),
        )
        if spec is None or spec.loader is None:
            print(error("Unable to create module loader."))
            return None
        module = importlib.util.module_from_spec(spec)
        if module is None:
            print(error("Unable to create module object."))
            return None
        sys.modules[MODULE_NAME] = module
        spec.loader.exec_module(module)
        return module
    except ImportError as exc:
        sys.modules.pop(MODULE_NAME, None)
        print(error(f"Binary import failed: {exc}"))
        print(
            warning(
                "Check Python ABI, architecture, "
                "OS compatibility and native dependencies."
            )
        )
        return None
    except OSError as exc:
        sys.modules.pop(MODULE_NAME, None)
        print(error(f"Native loader error: {exc}"))
        return None
    except Exception as exc:
        sys.modules.pop(MODULE_NAME, None)
        print(error(f"Module initialization failed: {exc}"))
        return None
def execute_module(module):
    try:
        run_function = getattr(module, "run", None)
        if not callable(run_function):
            print(
                error(
                    f"'{MODULE_NAME}' does not contain "
                    "a callable run()."
                )
            )
            return False
        run_function()
        return True
    except KeyboardInterrupt:
        print()
        print(info("Program interrupted by user."))
        return False
    except SystemExit:
        raise
    except Exception as exc:
        print(error(f"Program execution failed: {exc}"))
        return False
def print_header():
    line = color("─" * 56, Colors.DIM)
    print()
    print(line)
    print(
        color(
            f"  {MODULE_NAME}",
            Colors.BOLD + Colors.CYAN,
        )
    )
    print(line)
def print_environment():
    version = (
        f"{sys.version_info.major}."
        f"{sys.version_info.minor}."
        f"{sys.version_info.micro}"
    )
    print(info(f"Platform   : {get_platform_name()}"))
    print(info(f"Python     : {version}"))
    print(info(f"Architecture: {platform.machine()}"))
    print(
        info(
            "Binary     : "
            f"{', '.join(get_binary_extensions())}"
        )
    )
def main():
    print_header()
    if not check_python_version():
        print()
        print(
            warning(
                "Start the program using Python 3.13.3."
            )
        )
        return 1
    try:
        directory = Path(__file__).resolve().parent
    except (OSError, RuntimeError) as exc:
        print(error(f"Unable to resolve runner directory: {exc}"))
        return 1
    print_environment()
    binary = find_binary(directory)
    if binary is None:
        print()
        print(error("Compatible binary not found."))
        print(info(f"Directory : {directory}"))
        if is_termux():
            print(info("Target    : Android / Termux"))
            print(info("Required  : Python-compatible .so"))
        elif platform.system().lower() == "windows":
            print(
                info(
                    "Required  : "
                    "protected_card.cp313-win_amd64.pyd"
                )
            )
        else:
            print(
                info(
                    "Required  : "
                    "compatible CPython 3.13.3 binary"
                )
            )
        return 1
    print(success(f"Binary loaded: {binary.name}"))
    try:
        size = binary.stat().st_size
        print(info(f"Size      : {size:,} bytes"))
    except OSError:
        pass
    module = load_binary(binary)
    if module is None:
        print()
        print(error("Unable to load binary."))
        return 1
    try:
        if not execute_module(module):
            return 1
        print(success("Program completed successfully."))
        return 0
    finally:
        sys.modules.pop(MODULE_NAME, None)
if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print()
        print(info("Program interrupted by user."))
        sys.exit(130)
    except Exception as exc:
        print(fatal(f"Unexpected runner error: {exc}"))
        sys.exit(1)