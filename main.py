import os,sys,base64,zlib,hashlib,json
def x(d,k):return bytes((b^k[i%len(k)])for i,b in enumerate(d))
EXT=".pyd" if sys.platform.startswith("win") else ".so"
BASE=os.path.dirname(os.path.abspath(__file__))
D=os.path.join(BASE,"nit_")
F=("__init__"+EXT,"inis"+EXT,"it_"+EXT,"core"+EXT)
def m():
 try:
  mk=hashlib.sha256(b"init-key").digest()
  with open(os.path.join(D,"meta.dat"),"rb") as f:d=f.read()
  meta=json.loads(base64.b64decode(x(d,mk)).decode())
  raw=base64.b64decode(meta["k"].encode())
  if hashlib.sha1(raw).hexdigest()!=meta["s1"]:raise SystemExit
  if hashlib.sha384(raw).hexdigest()!=meta["s384"]:raise SystemExit
  return meta,hashlib.sha256(raw).digest(),hashlib.sha1(raw).digest(),hashlib.sha384(raw).digest()
 except Exception:raise SystemExit
def l(meta):
 out=[]
 try:
  for i,n in enumerate(F):
   fp=os.path.join(D,n)
   if not os.path.isfile(fp):raise SystemExit
   with open(fp,"rb") as f:d=f.read()
   if hashlib.sha256(d).hexdigest()!=meta["h"][i]:raise SystemExit
   out.append(d)
  return b"".join(out)
 except Exception:raise SystemExit
def r():
 try:
  meta,k256,k1,k384=m()
  d=l(meta)
  d=x(d,k384[:32]);d=base64.b64decode(d)
  d=x(d,k1);d=base64.b64decode(d)
  d=x(d,k256);d=base64.b64decode(d)
  d=zlib.decompress(d)
  exec(d,{"__name__":"__main__","__file__":os.path.abspath(__file__),"__package__":None,"__cached__":None,"sys":sys})
 except Exception:raise SystemExit
if __name__=="__main__":r()
