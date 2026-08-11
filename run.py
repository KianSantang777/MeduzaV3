#!/usr/bin/env python3

import importlib.util
import os
import platform
import sys
from pathlib import Path


MODULE_NAME = "protected_card"


def is_termux():
    return (
        "TERMUX_VERSION" in os.environ
        or os.environ.get("PREFIX", "").startswith("/data/data/com.termux")
    )


def get_os_name():
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


def get_binary_extension():
    if is_termux():
        return ".so"

    system = platform.system().lower()

    if system == "windows":
        return ".pyd"

    if system == "darwin":
        return ".dylib"

    if system == "linux":
        return ".so"

    return ".so"


def find_binary(script_dir):
    extension = get_binary_extension()
    exact_path = script_dir / f"{MODULE_NAME}{extension}"

    if exact_path.is_file() and exact_path.stat().st_size > 0:
        return exact_path

    try:
        for file_path in script_dir.iterdir():
            if not file_path.is_file():
                continue

            if file_path.stat().st_size <= 0:
                continue

            if file_path.suffix.lower() != extension:
                continue

            if file_path.name.startswith(MODULE_NAME):
                return file_path

    except OSError as exc:
        print(f"[ERROR] Failed to scan directory: {exc}")
        sys.exit(1)

    return None


def load_and_run(binary_path):
    print(f"[INFO] Loading: {binary_path.name}")

    try:
        spec = importlib.util.spec_from_file_location(
            MODULE_NAME,
            binary_path,
        )

        if spec is None or spec.loader is None:
            raise ImportError(
                f"Unable to load {binary_path.name}"
            )

        module = importlib.util.module_from_spec(spec)
        sys.modules[MODULE_NAME] = module

        spec.loader.exec_module(module)

        run_function = getattr(module, "run", None)

        if not callable(run_function):
            raise AttributeError(
                f"{MODULE_NAME} does not contain run()"
            )

        run_function()

    except Exception as exc:
        print(f"[ERROR] {exc}")
        sys.exit(1)


def main():
    print("=" * 50)
    print(f"  {MODULE_NAME}")
    print("=" * 50)

    script_dir = Path(__file__).resolve().parent
    current_os = get_os_name()
    extension = get_binary_extension()

    print(f"[INFO] Detected OS: {current_os}")
    print(f"[INFO] Expected binary: {extension}")

    binary = find_binary(script_dir)

    if binary is None:
        print()
        print("=" * 50)
        print(f"  ERROR: Binary not found for {current_os}")
        print("=" * 50)
        print()
        print(f"Expected: {MODULE_NAME}{extension}")
        sys.exit(1)

    load_and_run(binary)


if __name__ == "__main__":
    main()