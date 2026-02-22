# -*- coding: utf-8 -*-
import os,sys,base64,zlib,hashlib,json

def x(d,k):return bytes((b^k[i%len(k)])for i,b in enumerate(d))

BASE=os.path.dirname(os.path.abspath(__file__))
D=os.path.join(BASE,"nit_")
F=("__init__.pyd","inis.pyd","it_.pyd","core.pyd")

def m():
 mk=hashlib.sha256(b"init-key").digest()
 with open(os.path.join(D,"meta.dat"),"rb") as f:d=f.read()
 meta=json.loads(base64.b64decode(x(d,mk)).decode())
 raw=base64.b64decode(meta["k"].encode())
 k=hashlib.sha256(raw).digest()
 return meta,k

def l(meta):
 p=[]
 for i,n in enumerate(F):
  fp=os.path.join(D,n)
  if not os.path.isfile(fp):raise SystemExit("file missing")
  with open(fp,"rb") as f:d=f.read()
  if hashlib.sha256(d).hexdigest()!=meta["h"][i]:
   raise SystemExit("integrity fail")
  p.append(d)
 return b"".join(p)

def r():
 meta,k=m()
 d=l(meta)
 d=x(d,k[::-1])
 d=base64.b64decode(d)
 d=x(d,k)
 d=base64.b64decode(d)
 d=zlib.decompress(d)

 # ===== FIX CONTEXT =====
 ctx={
  "__name__":"__main__",
  "__file__":os.path.abspath(__file__),
  "__package__":None
 }

 exec(d,ctx)

if __name__=="__main__":r()
