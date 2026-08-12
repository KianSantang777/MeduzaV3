#!/usr/bin/env python3
from __future__ import annotations
import sys, os, hashlib, hmac, json, base64, zlib
from pathlib import Path
from typing import List, Dict, Any
from dataclasses import dataclass
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend

VERSION="2.0.0"; SALT_SIZE=32; NONCE_SIZE=12; KEY_SIZE=32
HASH_SIZE=32; PAYLOAD_COUNT=3
SALT_TOKEN="wcaw4KLwxabE5cPL0357xnhgvWf6S3nAhut2itAnd7yYkJ4AhKH8GVld/VH/UIhJpkl050ntr6T0vip6jED2Ig=="; VERIFICATION_TOKEN="oOk00ynrGrppXU9X1Y2eZhoSzqxB6ektfi79BFRemws="
OBF_PASSWORD="V3EwY9oO9RqOUQLrdCOZ3kcJgCu9ZsFyhGvxLH2aC17l"; ANTI_TAMPER_B64="eyJmaWxlX2hhc2hlcyI6IHt9LCAibWFuaWZlc3RfaGFzaCI6ICI4YzNkZWUxMTQyOWFmNGEzNDU0M2VhYWRlZjQ0OTczMzZjYzAyNzk1OGRhZGZlZjBhNjU5Y2Q3OGE3NzhkOGQ2Y2YyZjZmNTVlODljY2UwYzMxZjgzNDE4NjRkMmQ4NzciLCAibG9hZGVyX2hhc2giOiAiZjZkNDVmMDAwMmYxMDhmMzIwZWY1OGQyZTJhOWFlMDU2YjkzM2YwMGFmYzBiYTUwNDA5YTc4MjNmYmI3OGY3ZGEzYmI1ZmRkZWU2NjZkZDY4ZGQ3MzRkMTc1YTA5MmU1IiwgInRpbWVzdGFtcCI6ICIyMDI2LTA4LTEyVDIyOjEyOjU2LjgyNDg2NCIsICJzaWduYXR1cmUiOiAiNDM4MWU2NzM1MGY0YjYzZWEwNzA4YmIwMzU4M2U5ZWEwYTQwMDFkNTQwMTAyNDRlOTFhMDJjYTIyOTBiNTAxZjg0MTU2NmJlOWNiOTYzYjlkMTQ2ZThiNjhjNmI1NmQ5ZTBhMDM0MTRjNzlmYWJmYjA5ZTQwYzUyMTFiN2Y4NTEiLCAiZmlsZV9zaWdzIjoge30sICJjaGVja3N1bSI6ICIweDAifQ=="
OBFUSCATION_KEY=bytes([0x3A,0x7F,0x2D,0x8E,0x41,0xB9,0x56,0xC2,0x1D,0x4E,0xA7,0x38,0x6F,0xD5,0x92,0x0B,0x45,0xCC,0x67,0xF1,0x2A,0x8D,0x40,0xB6,0x59,0xC3,0x1E,0x4F,0xA8,0x39,0x6C,0xD6])

class ___(Exception): pass
class __1(___): pass
class __2(___): pass
class __3(___): pass
class __4(___): pass
class __5(___): pass
class __6(___): pass

@dataclass
class _:
    identifier: str
    version: str
    length: int
    digest: str
    index: int

@dataclass
class __:
    loader_identity: str
    payload_count: int
    payloads: List[_]
    final_auth: str
    version: str
    salt_token: str
    verification_token: str
    compression: bool
    compressed_sizes: List[int]
    xm: Dict[str, Any]

def _0A(p,s):
    k=PBKDF2HMAC(algorithm=hashes.SHA256(),length=KEY_SIZE*2,salt=s,iterations=600000,backend=default_backend())
    return k.derive(p)

def _0B(p):
    c=[]; pv=b"\x00"*HASH_SIZE
    for x in p:
        h=hashlib.sha256(x+pv).digest(); c.append(h); pv=h
    return c

def _0C(l,c,p):
    a=l.encode()
    for h in c: a+=h
    for m in p: a+=str(m.index)+":"+m.digest
    return hashlib.sha256(a).hexdigest()

def _0D(l,c,p,m):
    return hmac.new(m,_0C(l,c,p).encode(),hashlib.sha256).digest()

def _0E(e,k,n): return AESGCM(k).decrypt(n,e,None)
def _0F(c): return zlib.decompress(c)

def _0G(p,m):
    e=_0B(p)
    for i,(x,mm) in enumerate(zip(p,m.payloads)):
        if hashlib.sha256(x+(e[i-1] if i>0 else b"\x00"*HASH_SIZE)).digest()!=e[i]: return False
        if hashlib.sha256(x).hexdigest()!=mm.digest: return False
    return True

def _0H(p):
    if not p.exists(): raise __1("Missing: "+p.name)
    d=p.read_bytes()
    if not d: raise __1("Empty: "+p.name)
    return d

def _0I():
    try:
        d=base64.b64decode(OBF_PASSWORD); pl=d[0]; ob=d[1:1+pl]
        return bytes(a^b for a,b in zip(ob,OBFUSCATION_KEY[:pl])).decode("utf-8")
    except: raise __3("Auth failed")

def _0J(ed,p,m):
    try: st=base64.b64decode(m.salt_token)
    except: raise __4("Invalid salt")
    if len(st)!=SALT_SIZE+32: raise __4("Salt length error")
    s,at=st[:SALT_SIZE],st[SALT_SIZE:]
    pwd = p if isinstance(p, str) else p.decode()
    if not hmac.compare_digest(hmac.new(s,pwd.encode(),hashlib.sha256).digest(),base64.b64decode(VERIFICATION_TOKEN)):
        raise __3("Auth failed")
    mk=_0A(pwd.encode(),s); ek,hk=mk[:KEY_SIZE],mk[KEY_SIZE:]
    dc=[]
    for i,e in enumerate(ed):
        try: n=e[:NONCE_SIZE]; dc.append(_0E(e[NONCE_SIZE:],ek,n))
        except: raise __4("Segment "+str(i+1)+" corrupted")
    if not _0G(dc,m): raise __2("Integrity error")
    return b"".join(dc).decode("utf-8")

def _0K(s):
    try:
        c=compile(s,"<protected>","exec")
        exec(c,{"__name__":"__main__","__file__":__file__})
    except SyntaxError as e: raise __4("Syntax error: "+str(e))
    except Exception as e: raise ___("Exec error: "+str(e))

def _0L():
    try:
        from cryptography.hazmat.primitives.ciphers.aead import AESGCM
        from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
        from cryptography.hazmat.primitives import hashes
        from cryptography.hazmat.backends import default_backend
    except: raise __5("Missing dep")
    sd=Path(__file__).parent.resolve(); bn="card"
    pf=[sd/(bn+"1_dfa.cnc"),sd/(bn+"2_dfa.cnc"),sd/(bn+"3_dfa.cnc")]
    for p in pf:
        if not p.exists(): raise __1("Missing: "+p.name)
    try:
        d1=_0H(pf[0]); c1=json.loads(d1.decode("utf-8"))
        md=c1["manifest"]; pms=[_(**p) for p in md["payloads"]]
        mn=__(md["loader_identity"],md["payload_count"],pms,md["final_auth"],md["version"],
              md["salt_token"],md["verification_token"],md["compression"],md["compressed_sizes"],md["xm"])
        if mn.loader_identity!="XNC_RUNTIME_"+VERSION: raise __2("Identity mismatch")
        if mn.payload_count!=PAYLOAD_COUNT: raise __2("Count mismatch")
        comp_segs=[base64.b64decode(s) for s in c1["compressed_segments"]]
        enc_segs=[_0F(s) for s in comp_segs]
    except json.JSONDecodeError: raise __4("Manifest error")
    except Exception as e: raise __1("Cannot load: "+str(e))
    pw=_0I()
    try: src=_0J(enc_segs,pw.encode(),mn)
    except (__2,__3,__4): raise
    except: raise ___("Decryption failed")
    _0K(src)

if __name__=="__main__":
    try: _0L()
    except __1 as e: print("ERROR: "+str(e),file=sys.stderr); sys.exit(1)
    except __2 as e: print("ERROR: "+str(e),file=sys.stderr); sys.exit(1)
    except __3 as e: print("ERROR: "+str(e),file=sys.stderr); sys.exit(1)
    except __4 as e: print("ERROR: "+str(e),file=sys.stderr); sys.exit(1)
    except __5 as e: print("ERROR: "+str(e),file=sys.stderr); sys.exit(1)
    except __6 as e: print("ERROR: "+str(e),file=sys.stderr); sys.exit(1)
    except ___ as e: print("ERROR: "+str(e),file=sys.stderr); sys.exit(1)
