#!/usr/bin/env python3
import sys,os,hashlib,hmac,base64,platform,struct
from pathlib import Path
VER="5.2.0"
IT=1000000
SL=32
KS=32
HS=64
DN=["cye_os","chfd_ofc2","scr_dat","main_os"]
OB1=bytes([0x5a,0x3f,0x8e,0x2d,0x4b,0xc7,0x91,0x6a,0x1e,0x5d,0x2f,0x8c,0x43,0xb9,0x76,0x2a,0x9f,0x4e,0xc3,0x18,0x7d,0x2c,0x9a,0x5b,0x34,0x8f,0x2e,0x7b,0x4c,0xd1,0x86,0x3b])
OB2=bytes([0x2f,0x7c,0x4a,0xe9,0x1b,0x58,0xd3,0x6f,0x8a,0xb2,0x4e,0xc5,0x91,0x3d,0x7f,0x2a,0xe8,0x4b,0x9c,0x1f,0x6d,0xa3,0x5e,0x8f,0x2c,0xb7,0x4a,0xd1,0x7e,0x93,0x6b,0xc2])
AH="88c8f273a76714a893171980ebf87fdf1ae6adf4c9a59e3cb3f6c2a91c33ef771506697c29659e24e7bcc72bd970628305f85d8bc5dcc3e1c874121aeb4e20fb"
AH_RAW="iMjyc6dnFKiTFxmA6/h/3xrmrfTJpZ48s/bCqRwz73cVBml8KWWeJOe8xyvZcGKDBfhdi8Xcw+HIdBIa604g+w=="
class E(Exception):pass
class E1(E):pass
class E3(E):pass
class E4(E):pass
class E5(E):pass
_do=hmac.compare_digest
_rd=base64.b64decode
def _kx(p,s,n):return hashlib.pbkdf2_hmac("sha512",p,s,n,dklen=KS*2)
def _sd(d,k):
    h=hashlib.sha512(k).digest()
    r=[]
    for i in range(0,len(d),32):
        c=d[i:i+32]
        ctr=struct.pack(">Q",i//32)
        k2=hashlib.sha512(h+ctr).digest()[:len(c)]
        r.append(bytes(a^b for a,b in zip(c,k2)))
    return b"".join(r)
def _se(d,k):return _sd(d,k)
def _unobf(b,k):
    try:
        d=_rd(b);l=d[0]
        return bytes(d[i+1]^k[i%len(k)]for i in range(l)).decode()
    except:raise E3("Init failed")
def _chkd():return sys.gettrace()is not None
def _chkp():
    r=[]
    try:
        if platform.system()=='Windows':
            import ctypes
            try:
                if ctypes.windll.kernel32.IsDebuggerPresent():r.append(1)
            except:pass
        elif platform.system() in('Linux','Darwin','FreeBSD'):
            try:
                with open('/proc/self/status','rb')as f:
                    if b'TracerPid:\t0'not in f.read():r.append(1)
            except:pass
    except:pass
    return r
def _chkv():
    r=[]
    try:
        if platform.system()=='Windows':
            import ctypes
            try:
                h=ctypes.windll.kernel32.OpenProcess(0x1000,0,os.getpid())
                if h:
                    v=ctypes.c_int(0)
                    ctypes.windll.kernel32.CheckRemoteDebuggerPresent(h,ctypes.byref(v))
                    ctypes.windll.kernel32.CloseHandle(h)
                    if v.value:r.append(1)
            except:pass
    except:pass
    return r
def _blk():return _chkd()or _chkp()or _chkv()
def _gpth():return str(Path(__file__).parent.resolve())
def _gnm():return Path(__file__).stem.replace("_run","").replace("_x","")
def _lfs():p=_gpth();n=_gnm();return[Path(p)/(n+d)for d in DN]
TK="m5hFnAAocxIK68HEbrIDRj6QOISSV+1x5bPnwf1ht94FU5Wk6AJxRge5SZfKblFMiMjyc6dnFKiTFxmA6/h/3xrmrfTJpZ48s/bCqRwz73cVBml8KWWeJOe8xyvZcGKDBfhdi8Xcw+HIdBIa604g+w=="
OP="YGMGtxRy/qhTJ2QWtXqATxOmd/orTx+rA2zXdiMUid5xE3vKaQ+D1S5WFWfEC/E6ZtMCj1QxHKoUBMAeNHyeyQsVD8EdBPfeWlFtYLwMiTka0H6MKDIc1WsEvx40A57JdA=="
def _proc():
    if _blk():E5("Detected");os._exit(5)
    fs=_lfs()
    for f in fs:
        if not f.exists():E1("Missing: "+f.name);os._exit(1)
    try:
        ps=[f.read_bytes()for f in fs]
    except:
        E1("Load error");os._exit(1)
    try:
        pw=_unobf(OP,OB1)
    except:
        E3("Auth init");os._exit(3)
    try:
        dt=_rd(TK)
    except:
        E4("Token invalid");os._exit(4)
    if len(dt)!=SL+16+HS:E4("Token error");os._exit(4)
    s,vs,ph=dt[:SL],dt[SL:SL+16],dt[SL+16:]
    ah_bytes=_rd(AH_RAW)
    if not _do(ph,ah_bytes):E3("Auth failed");os._exit(3)
    mk=_kx(pw.encode(),s,IT)
    ek=mk[:KS]
    try:
        dc=b"".join(ps)
        dc=_sd(dc[16:],ek+vs)
        dc=_sd(dc,ek)
    except:
        E3("Decrypt failed");os._exit(3)
    try:
        code=dc.decode("utf-8")
    except:
        E1("Decode error");os._exit(1)
    try:
        c=compile(code,"<exec>","exec")
        g={"__name__":"__main__","__file__":__file__}
        exec(c,g)
        for k in list(g.keys()):
            if k not in("__name__","__file__"):del g[k]
    except SystemExit:raise
    except SyntaxError:E4("Code error");os._exit(4)
    except:E("Exec error");os._exit(6)
if __name__=="__main__":
    try:_proc()
    except E1:sys.exit(1)
    except E3:sys.exit(3)
    except E4:sys.exit(4)
    except E5:sys.exit(5)
    except E:sys.exit(6)
    except SystemExit as e:sys.exit(e.code)