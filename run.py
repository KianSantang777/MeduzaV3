#!/usr/bin/env python3
"""
Runner script - Auto-detects your OS and runs the program
Usage: python run.py
"""
import os, sys, platform, importlib.util, sysconfig
from pathlib import Path


MODULE_NAME = "protected_card"


def get_os_name():
    """Get human-readable OS name"""
    os_name = platform.system().lower()
    if os_name == "windows":
        return "Windows"
    elif os_name == "darwin":
        return "macOS"
    elif os_name == "linux":
        return "Linux"
    return os_name


def get_binary_extension():
    """Get the binary extension for current OS"""
    os_name = platform.system().lower()
    if os_name == "windows":
        return ".pyd"
    elif os_name == "darwin":
        return ".dylib"
    return ".so"


def find_binary(script_dir):
    """Find the binary file for current OS"""
    ext = get_binary_extension()
    base = MODULE_NAME

    # Try exact match first
    exact = script_dir / (base + ext)
    if exact.exists() and exact.stat().st_size > 0:
        return exact

    # Search for any matching binary
    for f in script_dir.iterdir():
        if not f.is_file():
            continue
        stem = f.stem
        # Match if stem starts with module name (handles cp313-win_amd64 suffix)
        if stem.startswith(base) or base.startswith(stem.split(".cp")[0] if ".cp" in stem else stem):
            ext_lower = f.suffix.lower()
            if ext_lower in [".pyd", ".so", ".dylib"] or ".cp3" in ext_lower:
                if f.stat().st_size > 0:
                    return f

    return None


def load_and_run(binary_path):
    """Load the binary module and run it"""
    print("[INFO] Loading: " + binary_path.name)

    spec = importlib.util.spec_from_file_location(MODULE_NAME, str(binary_path))
    if not spec or not spec.loader:
        print("[ERROR] Failed to load module")
        sys.exit(1)

    module = importlib.util.module_from_spec(spec)
    sys.modules[MODULE_NAME] = module

    try:
        spec.loader.exec_module(module)
    except Exception as e:
        print("[ERROR] " + str(e))
        import traceback
        traceback.print_exc()
        sys.exit(1)

    if hasattr(module, "run"):
        module.run()
    else:
        print("[ERROR] Module missing run function")
        sys.exit(1)


def main():
    print("=" * 50)
    print("  " + MODULE_NAME)
    print("=" * 50)

    script_dir = Path(__file__).parent.resolve()
    user_os = get_os_name()

    print("[INFO] Detected OS: " + user_os)

    binary = find_binary(script_dir)

    if binary:
        load_and_run(binary)
    else:
        print()
        print("=" * 50)
        print("  ERROR: Binary not found for " + user_os)
        print("=" * 50)
        print()
        print("This program was compiled for a different OS.")
        print()
        print("SOLUTION:")
        print("  Ask the developer to compile for " + user_os)
        print("  Or run: python build.py")
        print()
        sys.exit(1)


if __name__ == "__main__":
    main()
