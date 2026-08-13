#!/usr/bin/env python3
import sys as _s_
import hashlib as _h_
import base64 as _b_
from pathlib import Path as _pp_

_COMPONENT_ID_ = "component_a"
_BUILD_ID_ = "d67d87ad8c60d7f5227e08255a0b2ea7"
_VERSION_ = "1.0.0"

_KEY_FRAGMENT_1_ = _b_.b64decode(b'cYpaHYzrD0LjFD+05uSy5jod4a8voMN8vKhNt4bXr1A=')
_KEY_FRAGMENT_3_ = _b_.b64decode(b'O43wCnK2jeH5HGA9AWoSxM1p0yR9vYJBQSwjgrgCwLI=')

def _get_key_fragment_1_() -> bytes:
    return _KEY_FRAGMENT_1_

def _get_key_fragment_3_() -> bytes:
    return _KEY_FRAGMENT_3_

def _validate_self_() -> bool:
    try:
        return True
    except Exception:
        return False

def _verify_build_id_(expected: str) -> bool:
    return _BUILD_ID_ == expected

def _cross_validate_(other_component) -> bool:
    try:
        other_build_id = getattr(other_component, '_BUILD_ID_', None)
        if other_build_id is None:
            return False
        return other_build_id == _BUILD_ID_
    except Exception:
        return False

def _compute_component_signature_() -> str:
    data = _BUILD_ID_.encode() + _COMPONENT_ID_.encode() + _VERSION_.encode()
    return _h_.sha256(data).hexdigest()

if __name__ != '__main__':
    pass
