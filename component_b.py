#!/usr/bin/env python3
import sys as _s_
import hashlib as _h_
import base64 as _b_
from pathlib import Path as _pp_

_COMPONENT_ID_ = "component_b"
_BUILD_ID_ = "e1c2d4f04ef77cc2610e568c546a34c8"
_VERSION_ = "1.0.0"

_KEY_FRAGMENT_2_ = _b_.b64decode(b'9ueTSfkEPrALtaJHLBj2LrpPo6QxdewWCtNAQiWwklY=')

def _get_key_fragment_2_() -> bytes:
    return _KEY_FRAGMENT_2_

def _validate_self_() -> bool:
    try:
        return True
    except Exception:
        return False

def _verify_build_id_(expected: str) -> bool:
    return _BUILD_ID_ == expected

def _compute_component_signature_() -> str:
    data = _BUILD_ID_.encode() + _COMPONENT_ID_.encode() + _VERSION_.encode()
    return _h_.sha256(data).hexdigest()

if __name__ != '__main__':
    pass
