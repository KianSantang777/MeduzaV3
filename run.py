#!/usr/bin/env python3
import sys,os,hashlib,hmac,base64,platform
from pathlib import Path
ITERATIONS=800000;SALT_SIZE=32;NONCE_SIZE=12;KEY_SIZE=32;HMAC_SIZE=32
OBF_KEY=bytes([0x5A,0x3F,0x8E,0x2D,0x4B,0xC7,0x91,0x6A,0x1E,0x5D,0x2F,0x8C,0x43,0xB9,0x76,0x2A,0x9F,0x4E,0xC3,0x18,0x7D,0x2C,0x9A,0x5B,0x34,0x8F,0x2E,0x7B,0x4C,0xD1,0x86,0x3B])
AUTH_HASH='8ae128b7030f8cdec40fb90726eb2965b320b449633d2b4cbe9584bed6dcc0d1'
class _E(Exception):pass
class _E1(_E):pass
class _E3(_E):pass
class _E4(_E):pass
class _E5(_E):pass
def _ri(a,b):return hmac.compare_digest(a,b)
def _kx(p,s,n):return hashlib.pbkdf2_hmac('sha256',p,s,n,dklen=KEY_SIZE*2)
def _cd(d,k,n):
    try:
        from cryptography.hazmat.primitives.ciphers.aead import AESGCM
        return AESGCM(k[:KEY_SIZE]).decrypt(n,d,None)
    except:
        if len(d)<16:raise ValueError('Too short')
        ct,mac=d[:-16],d[-16:]
        if not _ri(mac,hmac.new(k[:KEY_SIZE],n+ct,hashlib.sha256).digest()[:16]):raise ValueError('Auth failed')
        from cryptography.hazmat.primitives.ciphers import Cipher,algorithms,modes
        from cryptography.hazmat.backends import default_backend
        return Cipher(algorithms.AES(k[:KEY_SIZE]),modes.CTR(n),backend=default_backend()).decryptor().update(ct)+Cipher(algorithms.AES(k[:KEY_SIZE]),modes.CTR(n),backend=default_backend()).decryptor().finalize()
def _unobf(b):
    try:
        d=base64.b64decode(b)
        l=d[0]
        return bytes(d[i+1]^OBF_KEY[i%len(OBF_KEY)]for i in range(l)).decode()
    except:raise _E3('Init failed')
def _sd():
    r=[]
    try:
        if os.environ.get('PYCHARM_DEBUG') or os.environ.get('PYDEVD'):r.append(1)
    except:pass
    return r
def _ptd():
    r=[]
    try:
        import threading
        if len(threading.enumerate())>100:r.append(1)
    except:pass
    try:
        if platform.system()=='Windows':
            import ctypes
            kernel32=ctypes.windll.kernel32
            kernel32.IsDebuggerPresent.restype=ctypes.c_bool
            if kernel32.IsDebuggerPresent():r.append(1)
    except:pass
    try:
        if platform.system() in('Linux','Darwin'):
            with open('/proc/self/status','rb')as f:
                for line in f:
                    if line.startswith(b'TracerPid:')and int(line.split()[1])!=0:r.append(1);break
    except:pass
    return r
def _pdd():
    r=[]
    try:
        if platform.system()=='Windows':
            import ctypes
            kernel32=ctypes.windll.kernel32
            PROCESS_QUERY_INFORMATION=0x0400
            h=kernel32.OpenProcess(PROCESS_QUERY_INFORMATION,0,os.getpid())
            if h:
                v=ctypes.c_int(0)
                kernel32.CheckRemoteDebuggerPresent(h,ctypes.byref(v))
                kernel32.CloseHandle(h)
                if v.value:r.append(1)
    except:pass
    try:
        if platform.system() in('Linux','Darwin'):
            with open('/proc/self/maps','rb')as f:
                for line in f:
                    if b'trace' in line.lower():r.append(1);break
    except:pass
    return r
def _chk():return any([_sd(),_ptd(),_pdd()])
TOKEN='qJAXed+A+ZzMu1POnzny1W3iFF8MbEQ0Svn4cnqQ9XQJ+LslV5WGAlQJvH2K4Si3Aw+M3sQPuQcm6yllsyC0SWM9K0y+lYS+1tzA0Q=='
OBF_PW='IT5e/Uk4pvULPn1I6iTfEk37KKR8Gwz9PVDoSh0rteBfPQ=='
def _gdata():
    sd=Path(__file__).parent.resolve()
    nm=Path(__file__).stem.replace('_run','').replace('_x','')
    enc=sd/(nm+'_dat')
    if not enc.exists():raise _E1('Missing: '+enc.name)
    try:
        return enc.read_bytes(),sd,nm
    except:raise _E1('Load error')
def _run():
    if _chk():raise _E5('Env blocked')
    enc_data,sd,nm=_gdata()
    try:ec=base64.b64decode(enc_data)
    except:raise _E1('Payload corrupted')
    try:pw=_unobf(OBF_PW)
    except:raise _E3('Auth init failed')
    try:dt=base64.b64decode(TOKEN)
    except:raise _E4('Token invalid')
    if len(dt)!=SALT_SIZE+NONCE_SIZE+HMAC_SIZE:raise _E4('Token error')
    s,vs,ph=dt[:SALT_SIZE],dt[SALT_SIZE:NONCE_SIZE+SALT_SIZE],dt[SALT_SIZE+NONCE_SIZE:]
    if not _ri(ph,bytes.fromhex(AUTH_HASH)):raise _E3('Auth failed')
    mk=_kx(pw.encode(),s,ITERATIONS)
    try:dc=_cd(ec,mk,vs)
    except ValueError:raise _E3('Decrypt failed')
    except:raise _E3('Decrypt error')
    try:code=dc.decode('utf-8')
    except:raise _E1('Decode error')
    try:
        c=compile(code,'<exec>','exec')
        g={'__name__':'__main__','__file__':__file__}
        exec(c,g)
        for k in list(g.keys()):
            if k not in('__name__','__file__'):del g[k]
    except SystemExit:raise
    except SyntaxError:raise _E4('Code error')
    except:raise _E('Exec error')
if __name__ == '__main__':
    try:_run()
    except _E1:sys.exit(1)
    except _E3:sys.exit(3)
    except _E4:sys.exit(4)
    except _E5:sys.exit(5)
    except _E:sys.exit(6)
    except SystemExit as e:sys.exit(e.code)