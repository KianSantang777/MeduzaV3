#!/usr/bin/env python3
import os
import sys
import platform
import importlib.util
from pathlib import Path

MODULE_NAME = "protected_card"

def _get_os_name():
    p = platform.system().lower()
    if p == "windows":
        return "Windows"
    if p == "darwin":
        return "macOS"
    return "Linux"

def _get_ext():
    p = platform.system().lower()
    if p == "windows":
        return ".pyd"
    if p == "darwin":
        return ".so"
    return ".so"

def _find_binary(script_dir):
    base = MODULE_NAME
    for f in script_dir.iterdir():
        if not f.is_file():
            continue
        stem = f.stem
        suffix = f.suffix.lower()
        if stem.startswith(base) or base.startswith(stem.split(".cp")[0] if ".cp" in stem else stem):
            if suffix in [".pyd", ".so"] or ".cp3" in suffix or suffix == ".dylib":
                try:
                    if f.stat().st_size > 0:
                        return f
                except OSError:
                    continue
    return None

def _load_module(binary_path):
    try:
        spec = importlib.util.spec_from_file_location(MODULE_NAME, str(binary_path))
        if not spec or not spec.loader:
            return None
        module = importlib.util.module_from_spec(spec)
        sys.modules[MODULE_NAME] = module
        spec.loader.exec_module(module)
        return module
    except Exception:
        return None

def main():
    print("=" * 50)
    print(f"  {MODULE_NAME}")
    print("=" * 50)
    script_dir = Path(__file__).parent.resolve()
    user_os = _get_os_name()
    print(f"[INFO] Detected OS: {user_os}")
    binary = _find_binary(script_dir)
    if binary:
        print(f"[INFO] Loading: {binary.name}")
        module = _load_module(binary)
        if module:
            if hasattr(module, "run"):
                module.run()
            else:
                print("[ERROR] Module missing run() function")
                sys.exit(1)
        else:
            print("[ERROR] Failed to load module")
            sys.exit(1)
    else:
        print()
        print("=" * 50)
        print(f"  ERROR: Binary not found for {user_os}")
        print("=" * 50)
        print()
        print("SOLUTION:")
        print(f"  python build.py")
        print(f"  python run.py")
        print()
        sys.exit(1)

if __name__ == "__main__":
    main()
