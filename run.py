import os, sys, platform, subprocess, importlib.util
from pathlib import Path


MODULE_NAME = "protected_card"


def get_os():
    return platform.system().lower()


def get_ext():
    os_name = get_os()
    if os_name == "windows":
        return ".pyd"
    elif os_name == "darwin":
        return ".dylib"
    return ".so"


def find_files(script_dir):
    ext = get_ext()
    compiled = None
    pyx = None
    for f in script_dir.iterdir():
        if f.is_file():
            if compiled is None and f.suffix == ext and f.stem.startswith(MODULE_NAME):
                compiled = f
            if pyx is None and f.suffix == ".pyx" and f.stem.startswith(MODULE_NAME):
                pyx = f
    return compiled, pyx


def compile_pyx(pyx_path, output_dir):
    import sysconfig
    print(f"[INFO] Compiling {pyx_path.name} for {get_os()}...")
    setup_code = f"""
from pathlib import Path
from setuptools import setup
from setuptools.extension import Extension
from Cython.Build import cythonize

setup(
    name="protected_card",
    ext_modules=cythonize(
        [Extension("protected_card", [str(Path(__file__).parent / "{pyx_path.name}")])],
        compiler_directives={"language_level": 3, "boundscheck": False, "wraparound": False}
    )
)
"""
    (output_dir / "setup.py").write_text(setup_code)
    result = subprocess.run(
        [sys.executable, "setup.py", "build_ext", "--inplace"],
        cwd=str(output_dir), capture_output=True, text=True, timeout=300
    )
    if result.returncode != 0:
        print(f"[ERROR] {result.stderr}")
        sys.exit(1)
    suffix = sysconfig.get_config_var("EXT_SUFFIX") or get_ext()
    compiled = output_dir / f"{MODULE_NAME}{suffix}"
    if not compiled.exists():
        for f in output_dir.rglob(f"{MODULE_NAME}*"):
            if f.suffix in (".pyd", ".so", ".dylib"):
                return f
        print("[ERROR] Compiled file not found")
        sys.exit(1)
    return compiled


def detect_module(script_dir):
    for pattern in ["*.pyx", "*.pyd", "*.so", "*.dylib"]:
        files = list(script_dir.glob(pattern))
        if files:
            return files[0].stem
    print("[ERROR] No module files found")
    sys.exit(1)


def find_or_compile(script_dir):
    os_name = get_os()
    compiled, pyx = find_files(script_dir)
    if compiled and compiled.exists():
        print(f"[INFO] Found: {compiled.name}")
        return compiled
    if os_name != "windows" and pyx and pyx.exists():
        print(f"[INFO] Compiling for {os_name}...")
        try:
            import Cython
        except ImportError:
            print("[ERROR] Cython required: pip install cython setuptools")
            sys.exit(1)
        return compile_pyx(pyx, script_dir)
    print(f"[ERROR] Need {MODULE_NAME}.pyd/.so or {MODULE_NAME}.pyx")
    sys.exit(1)


def load_module(module_path):
    module_dir = str(module_path.parent)
    module_stem = module_path.stem
    if module_dir not in sys.path:
        sys.path.insert(0, module_dir)
    print(f"[INFO] Loading: {module_path.name}")
    spec = importlib.util.spec_from_file_location(module_stem, str(module_path))
    if not spec or not spec.loader:
        print("[ERROR] Failed to load module")
        sys.exit(1)
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_stem] = module
    try:
        spec.loader.exec_module(module)
    except Exception as e:
        print(f"[RUNTIME ERROR] {e}")
        sys.exit(1)
    if hasattr(module, "run"):
        print("[INFO] Executing...")
        module.run()
    else:
        print("[ERROR] Module missing 'run' function")
        sys.exit(1)


def main():
    global MODULE_NAME
    script_dir = Path(__file__).parent.resolve()
    MODULE_NAME = detect_module(script_dir)
    print(f"[INFO] OS: {get_os()}")
    print(f"[INFO] Module: {MODULE_NAME}")
    module_path = find_or_compile(script_dir)
    load_module(module_path)


if __name__ == "__main__":
    main()
