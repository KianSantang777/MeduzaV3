#!/usr/bin/env python3
"""
Multi-version Python binary loader
Auto-detects and loads the correct binary for current Python version
"""
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

def _get_python_version():
    """Get current Python version in format: 38, 39, 310, 311, 312, 313"""
    return f"{sys.version_info.major}{sys.version_info.minor}"

def _get_platform_tag():
    """Get platform-specific tag for Cython binaries"""
    p = platform.system().lower()
    if p == "windows":
        return "win_amd64"
    if p == "darwin":
        arch = platform.machine()
        if arch == "arm64":
            return "darwin_arm64"
        return "darwin_x86_64"
    # Linux
    arch = platform.machine()
    return f"x86_64-linux-gnu"

def _get_cython_patterns():
    """Generate possible Cython filename patterns for current Python"""
    pyver = _get_python_version()
    platform_tag = _get_platform_tag()
    p = platform.system().lower()
    
    patterns = []
    
    if p == "windows":
        # module.cp313-win_amd64.pyd
        patterns.append(f"{MODULE_NAME}.cp{pyver}-win_amd64.pyd")
        patterns.append(f"{MODULE_NAME}.cp{pyver[0]}{pyver[1]}-win_amd64.pyd")
    elif p == "darwin":
        # module.cpython-313-darwin_arm64.so
        patterns.append(f"{MODULE_NAME}.cpython-{pyver}-{platform_tag}.so")
        patterns.append(f"{MODULE_NAME}.cpython-{pyver[0]}{pyver[1]}-{platform_tag}.so")
    else:
        # module.cpython-313-x86_64-linux-gnu.so
        patterns.append(f"{MODULE_NAME}.cpython-{pyver}-{platform_tag}.so")
        patterns.append(f"{MODULE_NAME}.cpython-{pyver[0]}{pyver[1]}-{platform_tag}.so")
    
    # Fallback patterns
    patterns.append(f"{MODULE_NAME}.pyd")
    patterns.append(f"{MODULE_NAME}.so")
    patterns.append(f"{MODULE_NAME}.dylib")
    
    return [p.replace("{MODULE_NAME}", MODULE_NAME).replace("{pyver}", pyver).replace("{platform_tag}", platform_tag) for p in patterns]

def _find_binary(script_dir):
    """Find binary matching current Python version"""
    patterns = _get_cython_patterns()
    
    # Try version-specific patterns first
    for pattern in patterns:
        for f in script_dir.iterdir():
            if f.name == pattern:
                try:
                    if f.stat().st_size > 0:
                        return f
                except OSError:
                    continue
    
    # Fallback: find any matching binary
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
