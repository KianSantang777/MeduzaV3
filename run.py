#!/usr/bin/env python3
import importlib.machinery
import importlib.util
import os
import platform
import sys
from pathlib import Path
MODULE_NAME = "protected_card"
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
    if system == "darwin":
        return (".so",)
    if system == "linux":
        return (".so",)
    return tuple(
        Path(suffix).suffix.lower()
        for suffix in importlib.machinery.EXTENSION_SUFFIXES
    )
def get_python_abi():
    implementation = platform.python_implementation()
    version = platform.python_version()
    machine = platform.machine()
    return f"{implementation} {version} {machine}"
def is_valid_binary(path):
    try:
        return (
            path.is_file()
            and path.stat().st_size > 0
            and os.access(path, os.R_OK)
        )
    except OSError:
        return False
def find_binary(script_dir):
    extensions = get_binary_extensions()
    try:
        candidates = []
        for path in script_dir.iterdir():
            if not path.is_file():
                continue
            if not path.name.startswith(MODULE_NAME):
                continue
            if not is_valid_binary(path):
                continue
            name_lower = path.name.lower()
            if any(name_lower.endswith(ext) for ext in extensions):
                candidates.append(path)
        if not candidates:
            return None
        exact_names = {
            f"{MODULE_NAME}{extension}"
            for extension in extensions
        }
        for path in candidates:
            if path.name in exact_names:
                return path
        extension_suffixes = tuple(
            suffix.lower()
            for suffix in importlib.machinery.EXTENSION_SUFFIXES
        )
        for path in candidates:
            if path.name.lower().endswith(extension_suffixes):
                return path
        candidates.sort(
            key=lambda item: item.stat().st_size,
            reverse=True,
        )
        return candidates[0]
    except OSError as exc:
        print(f"[ERROR] Unable to scan binary directory: {exc}")
        return None
def validate_binary(binary_path):
    try:
        if not binary_path.exists():
            return False, "Binary file does not exist."
        if not binary_path.is_file():
            return False, "Binary path is not a regular file."
        if binary_path.stat().st_size <= 0:
            return False, "Binary file is empty."
        if not os.access(binary_path, os.R_OK):
            return False, "Binary file is not readable."
        return True, None
    except OSError as exc:
        return False, f"Unable to validate binary: {exc}"
def create_module_spec(binary_path):
    try:
        spec = importlib.util.spec_from_file_location(
            MODULE_NAME,
            str(binary_path),
        )
        if spec is None:
            return None, "Python could not create the module specification."
        if spec.loader is None:
            return None, "Python could not create the binary module loader."
        return spec, None
    except Exception as exc:
        return None, f"Unable to create module specification: {exc}"
def load_binary(binary_path):
    valid, error = validate_binary(binary_path)
    if not valid:
        print(f"[ERROR] {error}")
        return None
    spec, error = create_module_spec(binary_path)
    if spec is None:
        print(f"[ERROR] {error}")
        return None
    try:
        module = importlib.util.module_from_spec(spec)
        if module is None:
            print("[ERROR] Failed to create module object.")
            return None
        sys.modules[MODULE_NAME] = module
        spec.loader.exec_module(module)
        return module
    except ImportError as exc:
        sys.modules.pop(MODULE_NAME, None)
        print(f"[ERROR] Binary import failed: {exc}")
        print("[INFO] Possible causes:")
        print("       - Wrong Python version or ABI")
        print("       - Wrong CPU architecture")
        print("       - Binary compiled for another OS")
        print("       - Missing native dependency")
        print("       - Invalid Python extension module")
        return None
    except OSError as exc:
        sys.modules.pop(MODULE_NAME, None)
        print(f"[ERROR] Native binary error: {exc}")
        print("[INFO] The binary may be incompatible with this platform.")
        return None
    except Exception as exc:
        sys.modules.pop(MODULE_NAME, None)
        print(f"[ERROR] Module initialization failed: {exc}")
        return None
def execute_module(module):
    try:
        run_function = getattr(module, "run", None)
        if not callable(run_function):
            print(
                f"[ERROR] Module '{MODULE_NAME}' "
                "does not expose a callable run()."
            )
            return False
        run_function()
        return True
    except KeyboardInterrupt:
        print("\n[INFO] Program interrupted by user.")
        return False
    except SystemExit:
        raise
    except Exception as exc:
        print(f"[ERROR] Program execution failed: {exc}")
        return False
def cleanup():
    sys.modules.pop(MODULE_NAME, None)
def print_environment():
    print(f"[INFO] Platform: {get_platform_name()}")
    print(f"[INFO] Python: {sys.version.split()[0]}")
    print(f"[INFO] ABI: {get_python_abi()}")
    print(f"[INFO] Architecture: {platform.machine()}")
    print(
        f"[INFO] Expected extension: "
        f"{', '.join(get_binary_extensions())}"
    )
def main():
    print("=" * 56)
    print(f"  {MODULE_NAME}")
    print("=" * 56)
    try:
        script_dir = Path(__file__).resolve().parent
    except (OSError, RuntimeError) as exc:
        print(f"[ERROR] Unable to resolve script directory: {exc}")
        return 1
    print_environment()
    binary = find_binary(script_dir)
    if binary is None:
        print()
        print("=" * 56)
        print(f"  ERROR: {MODULE_NAME} binary not found")
        print("=" * 56)
        print()
        print(f"[INFO] Directory: {script_dir}")
        print(
            "[INFO] Expected extension: "
            f"{', '.join(get_binary_extensions())}"
        )
        if is_termux():
            print("[INFO] Target: Android / Termux")
            print("[INFO] Required binary type: Python-compatible .so")
        return 1
    print(f"[INFO] Binary: {binary.name}")
    print(f"[INFO] Size: {binary.stat().st_size:,} bytes")
    module = load_binary(binary)
    if module is None:
        print()
        print("[ERROR] Unable to load the binary.")
        print("[INFO] Automatic recovery was attempted.")
        return 1
    try:
        if not execute_module(module):
            return 1
        return 0
    finally:
        cleanup()
if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n[INFO] Program interrupted by user.")
        sys.exit(130)
    except Exception as exc:
        print(f"[FATAL] Unexpected runner error: {exc}")
        sys.exit(1)