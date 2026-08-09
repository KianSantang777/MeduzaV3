#!/usr/bin/env python3
from __future__ import annotations
import sys
import os
import hashlib
import hmac
import json
import base64
from pathlib import Path
from typing import List, Dict, Any, Optional
from dataclasses import dataclass
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend

VERSION = "1.0.0"
SALT_SIZE = 32
NONCE_SIZE = 12
KEY_SIZE = 32
HASH_SIZE = 32
PAYLOAD_COUNT = 3
SALT_TOKEN = "mdpZaivZtUdwkkUIYWRdhLEjmtSTmr3dKK5zOSzvVgjq89/Er7/W9fR8lgs1iHmnSziQC3FgudtDrOcu39e2kQ=="
VERIFICATION_TOKEN = "ag06427FsWncdbT+FGlGpHFOUJqgyQDAbUY8YF+ci8E="
OBF_PASSWORD = "GkIHVdYZ4S66VifGVjy0/H8kogDIGvU4zgGb"
OBFUSCATION_KEY = bytes([0x3A, 0x7F, 0x2D, 0x8E, 0x41, 0xB9, 0x56, 0xC2,
                         0x1D, 0x4E, 0xA7, 0x38, 0x6F, 0xD5, 0x92, 0x0B,
                         0x45, 0xCC, 0x67, 0xF1, 0x2A, 0x8D, 0x40, 0xB6,
                         0x59, 0xC3, 0x1E, 0x4F, 0xA8, 0x39, 0x6C, 0xD6])

@dataclass
class PayloadMetadata:
    identifier: str
    version: str
    length: int
    digest: str
    index: int

@dataclass
class Manifest:
    loader_identity: str
    payload_count: int
    payloads: List[PayloadMetadata]
    final_auth: str
    version: str
    salt_token: str
    verification_token: str

class ProtectionError(Exception):
    pass

class ComponentMissingError(ProtectionError):
    pass

class IntegrityError(ProtectionError):
    pass

class AuthenticationError(ProtectionError):
    pass

class CorruptionError(ProtectionError):
    pass

class DependencyError(ProtectionError):
    pass

def derive_key(password: bytes, salt: bytes) -> bytes:
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=KEY_SIZE * 2,
        salt=salt,
        iterations=600000,
        backend=default_backend()
    )
    return kdf.derive(password)

def compute_chained_hashes(payloads: List[bytes]) -> List[bytes]:
    hashes_chain = []
    prev_hash = b"\x00" * HASH_SIZE
    for payload in payloads:
        current_hash = hashlib.sha256(payload + prev_hash).digest()
        hashes_chain.append(current_hash)
        prev_hash = current_hash
    return hashes_chain

def compute_final_auth(loader_id: str, hashes_chain: List[bytes],
                       payload_meta: List[PayloadMetadata]) -> str:
    auth_data = loader_id.encode()
    for h in hashes_chain:
        auth_data += h
    for meta in payload_meta:
        auth_data += f"{meta.index}:{meta.digest}".encode()
    return hashlib.sha256(auth_data).hexdigest()

def decrypt_payload(encrypted: bytes, key: bytes, nonce: bytes) -> bytes:
    aesgcm = AESGCM(key)
    return aesgcm.decrypt(nonce, encrypted, None)

def generate_auth_tag(loader_id: str, hashes_chain: List[bytes],
                      payload_meta: List[PayloadMetadata],
                      master_key: bytes) -> bytes:
    auth_data = compute_final_auth(loader_id, hashes_chain, payload_meta)
    return hmac.new(master_key, auth_data.encode(), hashlib.sha256).digest()

def verify_auth_tag(loader_id: str, hashes_chain: List[bytes],
                    payload_meta: List[PayloadMetadata],
                    master_key: bytes, expected_tag: bytes) -> bool:
    computed_tag = generate_auth_tag(loader_id, hashes_chain, payload_meta, master_key)
    return hmac.compare_digest(computed_tag, expected_tag)

def verify_integrity(payloads: List[bytes], manifest: Manifest) -> bool:
    expected_hashes = compute_chained_hashes(payloads)
    for i, (payload, meta) in enumerate(zip(payloads, manifest.payloads)):
        current_hash = hashlib.sha256(payload + (expected_hashes[i-1] if i > 0 else b"\x00" * HASH_SIZE)).digest()
        if current_hash != expected_hashes[i]:
            return False
        if hashlib.sha256(payload).hexdigest() != meta.digest:
            return False
    return True

def load_component(path: Path) -> bytes:
    if not path.exists():
        raise ComponentMissingError(f"Missing component: {path.name}")
    try:
        with open(path, "rb") as f:
            data = f.read()
        if len(data) == 0:
            raise ComponentMissingError(f"Empty component: {path.name}")
        return data
    except ComponentMissingError:
        raise
    except Exception:
        raise ComponentMissingError(f"Cannot read component: {path.name}")

def get_internal_password() -> str:
    try:
        decoded = base64.b64decode(OBF_PASSWORD)
        pwd_len = decoded[0]
        obfuscated_bytes = decoded[1:1 + pwd_len]
        key_extended = OBFUSCATION_KEY[:pwd_len]
        original = bytes(a ^ b for a, b in zip(obfuscated_bytes, key_extended))
        return original.decode("utf-8")
    except Exception:
        raise AuthenticationError("Internal authentication failed")

def decrypt_and_verify(encrypted_data: List[bytes], password: str,
                       manifest: Manifest) -> str:
    try:
        salt_token_bytes = base64.b64decode(manifest.salt_token)
    except Exception:
        raise CorruptionError("Invalid salt token format")

    if len(salt_token_bytes) != SALT_SIZE + 32:
        raise CorruptionError("Invalid salt token length")

    salt = salt_token_bytes[:SALT_SIZE]
    expected_auth_tag = salt_token_bytes[SALT_SIZE:]

    try:
        expected_verify_token = base64.b64decode(VERIFICATION_TOKEN)
        computed_verify_token = hmac.new(salt, password.encode(), hashlib.sha256).digest()
        if not hmac.compare_digest(computed_verify_token, expected_verify_token):
            raise AuthenticationError("Authentication failed")
    except Exception:
        raise AuthenticationError("Authentication failed")

    master_key = derive_key(password.encode(), salt)
    enc_key = master_key[:KEY_SIZE]
    hmac_key = master_key[KEY_SIZE:]

    decrypted = []
    for i, enc_segment in enumerate(encrypted_data):
        try:
            nonce = enc_segment[:NONCE_SIZE]
            ciphertext = enc_segment[NONCE_SIZE:]
            decrypted.append(decrypt_payload(ciphertext, enc_key, nonce))
        except Exception:
            raise CorruptionError(f"Corrupted payload segment {i+1}")

    payload_hashes = compute_chained_hashes(decrypted)

    if not verify_auth_tag(manifest.loader_identity, payload_hashes,
                          manifest.payloads, hmac_key, expected_auth_tag):
        raise AuthenticationError("Authentication failed")

    if not verify_integrity(decrypted, manifest):
        raise IntegrityError("Integrity verification failed")

    return b"".join(decrypted).decode("utf-8")

def execute_source(source_code: str) -> None:
    try:
        compiled = compile(source_code, "<protected>", "exec")
        namespace = {"__name__": "__main__", "__file__": __file__}
        exec(compiled, namespace)
    except SyntaxError as e:
        raise CorruptionError(f"Payload syntax error: {e}")
    except Exception as e:
        raise ProtectionError(f"Execution error: {e}")

def main() -> None:
    try:
        from cryptography.hazmat.primitives.ciphers.aead import AESGCM
        from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
        from cryptography.hazmat.primitives import hashes
        from cryptography.hazmat.backends import default_backend
    except ImportError:
        raise DependencyError("Missing dependency")

    script_dir = Path(__file__).parent.resolve()
    base_name = "card"

    payload_files = [
        script_dir / f"{base_name}1_dfa.cnc",
        script_dir / f"{base_name}2_dfa.cnc",
        script_dir / f"{base_name}3_dfa.cnc"
    ]

    for path in payload_files:
        if not path.exists():
            raise ComponentMissingError(f"Missing component: {path.name}")

    try:
        component1_data = load_component(payload_files[0])
        component1 = json.loads(component1_data.decode("utf-8"))

        manifest_dict = component1["manifest"]
        manifest_payloads = [PayloadMetadata(**p) for p in manifest_dict["payloads"]]
        manifest = Manifest(
            loader_identity=manifest_dict["loader_identity"],
            payload_count=manifest_dict["payload_count"],
            payloads=manifest_payloads,
            final_auth=manifest_dict["final_auth"],
            version=manifest_dict["version"],
            salt_token=manifest_dict["salt_token"],
            verification_token=manifest_dict["verification_token"]
        )

        encrypted_segments = [base64.b64decode(s) for s in component1["encrypted_segments"]]

    except json.JSONDecodeError:
        raise CorruptionError("Corrupted manifest")
    except Exception as e:
        raise ComponentMissingError(f"Cannot load manifest: {e}")

    if manifest.loader_identity != "XNC_RUNTIME_1.0.0":
        raise IntegrityError("Loader identity mismatch")

    if manifest.payload_count != PAYLOAD_COUNT:
        raise IntegrityError(f"Expected {PAYLOAD_COUNT} payloads")

    for i, enc_segment in enumerate(encrypted_segments):
        if len(enc_segment) < NONCE_SIZE + 16:
            raise CorruptionError(f"Payload {i+1} too short")

    password = get_internal_password()

    try:
        source_code = decrypt_and_verify(encrypted_segments, password, manifest)
    except (IntegrityError, AuthenticationError, CorruptionError):
        raise
    except Exception as e:
        raise ProtectionError(f"Decryption failed")

    execute_source(source_code)

if __name__ == "__main__":
    try:
        main()
    except ComponentMissingError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    except IntegrityError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    except AuthenticationError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    except CorruptionError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    except DependencyError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    except ProtectionError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
