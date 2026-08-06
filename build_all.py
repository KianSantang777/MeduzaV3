#!/usr/bin/env python3
"""
Cross-platform build script for protected_card
Auto-detects OS and builds the correct binary format.
Usage: python build_all.py
"""
import os, sys, subprocess, platform, shutil, sysconfig
from pathlib import Path

MODULE_NAME = "protected_card"
PYX_FILE = "protected_card.pyx"

def get_os():
    return platform.system().lower()

def get_ext_suffix():
    suffix = sysconfig.get_config_var("EXT_SUFFIX")
    if suffix:
        return suffix
    os_name = get_os()
    if os_name == "windows":
        return ".pyd"
    elif os_name == "darwin":
        return ".dylib"
    return ".so"

def check_dependencies():
    errors = []
    try:
        import setuptools
    except ImportError:
        errors.append("setuptools")
    try:
        import Cython
    except ImportError:
        errors.append("Cython")
    if errors:
        print("[ERROR] Missing dependencies: " + ", ".join(errors))
        print("[ERROR] Install with: pip install " + " ".join(errors))
        sys.exit(1)
    print("[OK] Dependencies verified")

def compile_for_current_os():
    os_name = get_os()
    ext = get_ext_suffix()
    output_file = Path(MODULE_NAME + ext)

    if output_file.exists():
        output_file.unlink()
        print("[INFO] Removed old: " + output_file.name)

    print("[INFO] Building for " + os_name + " -> " + output_file.name)

    setup_code = '''\
from pathlib import Path
from setuptools import setup
from setuptools.extension import Extension
from Cython.Build import cythonize

BASE = Path(__file__).parent

setup(
    name="__MODULENAME__",
    ext_modules=cythonize(
        [Extension("__MODULENAME__", [str(BASE / "__PYXFILE__")])],
        compiler_directives={
            "language_level": 3,
            "boundscheck": False,
            "wraparound": False,
            "cdivision": True,
        }
    )
)
'''.replace('__MODULENAME__', MODULE_NAME).replace('__PYXFILE__', PYX_FILE)

    with open("setup_temp.py", "w") as f:
        f.write(setup_code)

    try:
        result = subprocess.run(
            [sys.executable, "setup_temp.py", "build_ext", "--inplace"],
            capture_output=True, text=True, timeout=300
        )
        if result.returncode != 0:
            print("[ERROR] Build failed:")
            print(result.stderr)
            sys.exit(1)

        suffix = get_ext_suffix()
        candidates = [Path(MODULE_NAME + suffix)]

        for root, dirs, files in os.walk("."):
            for f in files:
                if f.startswith(MODULE_NAME) and (f.endswith(".pyd") or f.endswith(".so") or f.endswith(".dylib")):
                    src = Path(root) / f
                    if src.exists() and src.stat().st_size > 0:
                        candidates.append(src)

        compiled = None
        for candidate in candidates:
            if candidate.exists() and candidate.stat().st_size > 0:
                compiled = candidate
                break

        if not compiled:
            print("[ERROR] Compiled file not found")
            sys.exit(1)

        if compiled != output_file:
            shutil.move(str(compiled), str(output_file))
            for f in Path(".").glob(MODULE_NAME + "*"):
                if f.is_file() and f != output_file and (f.suffix in [".pyd", ".so", ".dylib"]):
                    f.unlink()

        size = output_file.stat().st_size
        print("[OK] Created: " + output_file.name + " (" + str(size) + " bytes)")

    finally:
        if Path("setup_temp.py").exists():
            Path("setup_temp.py").unlink()

def main():
    print("=" * 50)
    print("Cross-Platform Build Script")
    print("Module: " + MODULE_NAME)
    print("Source: " + PYX_FILE)
    print("=" * 50)

    if not Path(PYX_FILE).exists():
        print("[ERROR] " + PYX_FILE + " not found!")
        sys.exit(1)

    check_dependencies()
    compile_for_current_os()

    print("=" * 50)
    print("Build complete!")
    print("=" * 50)

if __name__ == "__main__":
    main()
