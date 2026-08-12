#!/usr/bin/env python3
from __future__ import annotations
import sys, os, hashlib, hmac, json, base64, zlib, struct
from pathlib import Path
from typing import List, Dict, Any
from dataclasses import dataclass

VERSION="2.0.0"; SALT_SIZE=32; NONCE_SIZE=12; KEY_SIZE=32
HASH_SIZE=32; PAYLOAD_COUNT=3
SALT_TOKEN="eIkgcGdzkemuXyzXZAG35DAnV0Yjg3HdQj48KXF10GHrocXjcgFdhejBORiqVOGqoNghVezbmv3ylu7YddxKiA=="; VERIFICATION_TOKEN="/53p1txBqeXkZ6XD5X9PVphc5RAlGwgGFFsqxPMVU/0="
OBF_PASSWORD="V3EwY9oO9RqOUQLrdCOZ3kcJgCu9ZsFyhGvxLH2aC17lCUwevXL1Go5RAut0I5neRwmAK71lwg/5FoxRAOcJXOYKTx2+cYgajS0Bl3cgmt1HCYMowRq8cQ=="; ANTI_TAMPER_B64="eyJmaWxlX2hhc2hlcyI6IHt9LCAibWFuaWZlc3RfaGFzaCI6ICI4YzNkZWUxMTQyOWFmNGEzNDU0M2VhYWRlZjQ0OTczMzZjYzAyNzk1OGRhZGZlZjBhNjU5Y2Q3OGE3NzhkOGQ2Y2YyZjZmNTVlODljY2UwYzMxZjgzNDE4NjRkMmQ4NzciLCAibG9hZGVyX2hhc2giOiAiZjZkNDVmMDAwMmYxMDhmMzIwZWY1OGQyZTJhOWFlMDU2YjkzM2YwMGFmYzBiYTUwNDA5YTc4MjNmYmI3OGY3ZGEzYmI1ZmRkZWU2NjZkZDY4ZGQ3MzRkMTc1YTA5MmU1IiwgInRpbWVzdGFtcCI6ICIyMDI2LTA4LTEyVDIyOjUxOjMyLjQwNDkxNiIsICJzaWduYXR1cmUiOiAiNDcxYjQ1MzU4OGYyZjI3MGE3NGE5N2VkMTFjMWM4MjJmOWY1NjRmNjE1MWRkZDBmOTE4OWQ4OGM4ZTMzNDUyYzkzMjBjNmQxOWQ4MWQ3YzFjZjhlZGQ0ZmFhMDhhMWM5OTY2MDY1YTMzOWRmMWJlZDk2NWQzMGFjYThkNWRmZjAiLCAiZmlsZV9zaWdzIjoge30sICJjaGVja3N1bSI6ICIweDAifQ=="
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

# Pure Python AES-256-CTR implementation
class _AES256CTR:
    SBOX=[0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16]
    RCON=[0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80,0x1b,0x36]
    def __init__(K,s):
        K.key=s;K.Nb=4;K.Nk=8;K.Nr=14;K._rk=K._ke(s)
    def _sb(S,x):
        return [S.SBOX[b]for b in x]
    def _sr(S,x):
        return[x[0],x[5],x[10],x[15],x[4],x[9],x[14],x[3],x[8],x[13],x[2],x[7],x[12],x[1],x[6],x[11]]
    def _mc(S,x):
        def M(a,b):
            if not a or not b:return 0
            r=0
            for _ in range(8):
                if b&1:r^=a
                a=(a<<1&255)^(0x1b if a&0x80 else 0);b>>=1
            return r
        r=[]
        for i in range(4):
            c=[x[i],x[i+4],x[i+8],x[i+12]]
            r.extend([M(c[0],2)^M(c[1],3)^c[2]^c[3],c[0]^M(c[1],2)^M(c[2],3)^c[3],c[0]^c[1]^M(c[2],2)^M(c[3],3),M(c[0],3)^c[1]^c[2]^M(c[3],2)])
        return r
    def _ar(S,x,rk):return[s^rk[i]for i,s in enumerate(x)]
    def _ke(K,k):
        rk=[list(k[i*4:(i+1)*4])for i in range(4)]
        for i in range(4,4*(K.Nr+1)):
            t=list(rk[i-1])
            if i%K.Nk==0:
                t=[K.SBOX[t[(j+1)%4]]for j in range(4)]
                t[0]^=K.RCON[i//K.Nk-1]
            elif K.Nk>6 and i%K.Nk==4:t=K._sb(t)
            rk.append([rk[i-K.Nk][j]^t[j]for j in range(4)])
        r=[]
        for w in range(K.Nr+1):
            r.append([])
            for c in range(4):r[w].extend([rk[c+w*4][j]for j in range(4)])
        return r
    def _eb(K,b):
        s=list(b);s=K._ar(s,K._rk[0])
        for r in range(1,K.Nr):
            s=K._sb(s);s=K._sr(s);s=K._mc(s);s=K._ar(s,K._rk[r])
        s=K._sb(s);s=K._sr(s);s=K._ar(s,K._rk[K.Nr])
        return bytes(s)
    def enc(K,p,n):
        ni=int.from_bytes(n,'big');c=bytearray()
        for i in range(0,len(p),16):
            cb=p[i:i+16];ct=ni+(i//16)
            ks=K._eb(ct.to_bytes(16,'big'))
            if len(cb)<16:ks=ks[:len(cb)]
            c.extend(a^b for a,b in zip(cb,ks))
        return bytes(c)

def _aes_gcm_dec(ct,k,n):
    if len(ct)<16:raise ValueError("Too short")
    return _aes_gcm_dec_impl(ct,k,n)

def _aes_gcm_dec_impl(ct,k,n):
    ac=ct[:-16];rm=ct[-16:]
    mi=n+ac;em=hmac.new(k,mi,hashlib.sha256).digest()[:16]
    if not hmac.compare_digest(rm,em):raise ValueError("Auth failed")
    aes=_AES256CTR(k);return aes.enc(ac,n)

def _0A(p,s):
    return hashlib.pbkdf2_hmac('sha256',p,s,600000,dklen=KEY_SIZE*2)

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

def _0E(e,k,n): return _aes_gcm_dec(e,k,n)
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
        # FIX: XOR entire password, cycling the obfuscation key if needed
        return bytes(ob[i] ^ OBFUSCATION_KEY[i % len(OBFUSCATION_KEY)] for i in range(pl)).decode("utf-8")
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
