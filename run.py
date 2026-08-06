import os, sys, platform, subprocess, importlib.util, sysconfig
from pathlib import Path


MODULE_NAME = "protected_card"


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


def get_abi_tag():
    suffix = sysconfig.get_config_var("EXT_SUFFIX")
    if not suffix:
        return ""
    for sep in ["-", "_"]:
        if sep in suffix and "cp3" in suffix:
            start = suffix.find("cp3")
            end = suffix.rfind(".")
            if end > start:
                return suffix[start:end]
    return ""


def strip_abi_tag(name):
    abi = get_abi_tag()
    if abi and name.endswith(abi):
        result = name[:-len(abi)]
        if result.endswith("."):
            result = result[:-1]
        return result
    return name


def find_compiled_file(script_dir):
    ext_suffix = get_ext_suffix()
    base_name = MODULE_NAME
    candidates = []
    if ext_suffix:
        candidates.append(script_dir / (base_name + ext_suffix))
    candidates.extend([
        script_dir / (base_name + ".pyd"),
        script_dir / (base_name + ".so"),
    ])
    for candidate in candidates:
        if candidate.exists() and candidate.stat().st_size > 0:
            return candidate
    for f in script_dir.iterdir():
        if f.is_file() and (strip_abi_tag(f.stem) == base_name or f.stem.startswith(base_name)):
            ext = f.suffix.lower()
            if ext in (".pyd", ".so", ".dylib") or ".cp3" in ext:
                if f.stat().st_size > 0:
                    return f
    return None


def find_pyx_file(script_dir):
    for f in script_dir.iterdir():
        if f.is_file() and f.suffix == ".pyx" and strip_abi_tag(f.stem) == MODULE_NAME:
            return f
    return None


def compile_pyx(pyx_path, output_dir):
    print("[INFO] Compiling " + pyx_path.name + " for " + get_os() + "...")
    mn = MODULE_NAME
    pn = pyx_path.name
    setup_code = (
        "from pathlib import Path\n",
        "from setuptools import setup\n",
        "from setuptools.extension import Extension\n",
        "from Cython.Build import cythonize\n",
        "\n",
        "setup(\n",
        '    name="' + mn + '",\n',
        "    ext_modules=cythonize(\n",
        '        [Extension(chr(34) + mn + chr(34), [str(Path(__file__).parent / (chr(34) + pn + chr(34)))])],\n',
        "        compiler_directives=" + '{"' + '\"language_level\": 3, \"boundscheck\": False, \"wraparound\": False}' + "}\n",
        "    )\n",
        ")\n",
    ),
    (output_dir / "setup.py").write_text(setup_code)
    result = subprocess.run(
        [sys.executable, "setup.py", "build_ext", "--inplace"],
        cwd=str(output_dir), capture_output=True, text=True, timeout=300
    )
    if result.returncode != 0:
        print("[ERROR] " + result.stderr)
        sys.exit(1)
    ext_suffix = get_ext_suffix()
    base_name = MODULE_NAME
    candidates = []
    if ext_suffix:
        candidates.append(output_dir / (base_name + ext_suffix))
    candidates.extend([
        output_dir / (base_name + ".pyd"),
        output_dir / (base_name + ".so"),
    ])
    for candidate in candidates:
        if candidate.exists() and candidate.stat().st_size > 0:
            return candidate
    for root, dirs, files in os.walk(output_dir):
        for f in files:
            if strip_abi_tag(f) == base_name and (f.endswith(".pyd") or f.endswith(".so")):
                return Path(root) / f
    print("[ERROR] Compiled file not found after build")
    sys.exit(1)


def detect_module(script_dir):
    for pattern in ["*.pyd", "*.so", "*.dylib", "*.pyx"]:
        files = list(script_dir.glob(pattern))
        if files:
            for f in files:
                stem = f.stem
                base = strip_abi_tag(stem)
                if base.startswith("protected_") or base.startswith("m_"):
                    return base
            return strip_abi_tag(files[0].stem)
    print("[ERROR] No module files found")
    sys.exit(1)


def find_or_compile(script_dir):
    os_name = get_os()
    compiled = find_compiled_file(script_dir)
    pyx = find_pyx_file(script_dir)
    if compiled and compiled.exists():
        print("[INFO] Found: " + compiled.name)
        return compiled
    if pyx and pyx.exists():
        print("[INFO] Compiling .pyx on " + os_name + "...")
        try:
            import Cython
        except ImportError:
            print("[ERROR] Cython required: pip install cython setuptools")
            sys.exit(1)
        return compile_pyx(pyx, script_dir)
    print("[ERROR] Need " + MODULE_NAME + ".pyd/.so or .pyx")
    sys.exit(1)


def load_module(module_path):
    module_dir = str(module_path.parent)
    module_stem = MODULE_NAME
    if module_dir not in sys.path:
        sys.path.insert(0, module_dir)
    print("[INFO] Loading: " + module_path.name)
    print("[INFO] Module stem: " + module_stem)
    spec = importlib.util.spec_from_file_location(module_stem, str(module_path))
    if not spec or not spec.loader:
        print("[ERROR] Failed to create module spec")
        sys.exit(1)
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_stem] = module
    try:
        spec.loader.exec_module(module)
    except Exception as e:
        print("[RUNTIME ERROR] " + str(e))
        import traceback
        traceback.print_exc()
        sys.exit(1)
    if hasattr(module, "run"):
        print("[INFO] Executing...")
        module.run()
    else:
        print("[ERROR] Module missing run function")
        sys.exit(1)


def main():
    global MODULE_NAME
    script_dir = Path(__file__).parent.resolve()
    MODULE_NAME = detect_module(script_dir)
    print("[INFO] OS: " + get_os())
    print("[INFO] Module: " + MODULE_NAME)
    module_path = find_or_compile(script_dir)
    load_module(module_path)


if __name__ == "__main__":
    main()
