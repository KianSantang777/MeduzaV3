#!/usr/bin/env python3
import sys as _s_
import os as _o_
import platform as _pl_
from pathlib import Path as _pp_
from typing import Tuple, Dict, Any, Optional

_BUILD_VERSION_ = "1.0.0"
_BUILD_ID_ = "568a6b6f8a720403c3e029ebca7108b9"

_RUNTIME_REQUIREMENTS_ = [
    "run.py",
    "runtime_core.py",
    "component_a.py",
    "component_b.py",
    "payload.dat",
    "fallback_aes.py"
]

_CAPABILITY_CACHE_ = {}

def _detect_capabilities_() -> Dict[str, Any]:
    global _CAPABILITY_CACHE_
    if _CAPABILITY_CACHE_:
        return _CAPABILITY_CACHE_
    caps = {
        'platform': _pl_.system().lower(),
        'platform_release': _pl_.release(),
        'machine': _pl_.machine(),
        'python_version': _s_.version_info[:3],
        'python_implementation': _pl_.python_implementation(),
        'has_secrets_module': True,
        'path_sep': _o_.sep,
    }
    try:
        caps['has_gettrace'] = hasattr(_s_, 'gettrace')
    except Exception:
        pass
    _CAPABILITY_CACHE_ = caps
    return caps

def _get_component_directory_() -> _pp_:
    if getattr(_s_, 'frozen', False):
        return _pp_(_s_.prefix).parent
    return _pp_(__file__).parent.resolve()

def _validate_environment_(caps: Dict[str, Any]) -> Tuple[bool, Optional[str]]:
    component_dir = _get_component_directory_()
    for req_file in _RUNTIME_REQUIREMENTS_:
        file_path = component_dir / req_file
        if not file_path.exists():
            return False, f"Missing required component: {req_file}"
        if file_path.stat().st_size == 0:
            return False, f"Empty component file: {req_file}"
    return True, None

def _check_debugger_present_() -> bool:
    try:
        if hasattr(_s_, 'gettrace') and _s_.gettrace() is not None:
            return True
    except Exception:
        pass
    return False

def _safe_shutdown_(exit_code: int = 1) -> None:
    try:
        _s_.exit(exit_code)
    except SystemExit:
        pass

def _secure_cleanup_() -> None:
    global _CAPABILITY_CACHE_
    _CAPABILITY_CACHE_ = {}

def _main_entry_() -> int:
    is_debug_mode = '--debug' in _s_.argv or '-d' in _s_.argv
    caps = _detect_capabilities_()

    valid, error = _validate_environment_(caps)
    if not valid:
        if is_debug_mode:
            print(f"ENVIRONMENT ERROR: {error}", file=_s_.stderr)
        _secure_cleanup_()
        _safe_shutdown_(1)

    if _check_debugger_present_():
        if is_debug_mode:
            print("RUNTIME NOTICE: Debugger detection active", file=_s_.stderr)
        _secure_cleanup_()
        _safe_shutdown_(1)

    try:
        from runtime_core import _initialize_protected_runtime_
        result = _initialize_protected_runtime_(__file__, caps, is_debug_mode)
        if not result[0]:
            if is_debug_mode:
                print(f"RUNTIME ERROR: {result[1]}", file=_s_.stderr)
            else:
                print("RUNTIME ERROR: Protected execution failed", file=_s_.stderr)
            _secure_cleanup_()
            _safe_shutdown_(1)
    except ImportError as e:
        if is_debug_mode:
            print(f"IMPORT ERROR: {e}", file=_s_.stderr)
        else:
            print("IMPORT ERROR: Failed to load runtime components", file=_s_.stderr)
        _secure_cleanup_()
        _safe_shutdown_(1)
    except Exception as e:
        if is_debug_mode:
            import traceback
            traceback.print_exc(file=_s_.stderr)
        else:
            print("RUNTIME ERROR: Execution failed", file=_s_.stderr)
        _secure_cleanup_()
        _safe_shutdown_(1)

    _secure_cleanup_()
    return 0

if __name__ == '__main__':
    exit_code = _main_entry_()
    _safe_shutdown_(exit_code)
