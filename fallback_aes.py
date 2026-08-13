
import struct
from typing import Tuple


class SimpleAES:

    SBOX = bytes([
        0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
        0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
        0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
        0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
        0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
        0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
        0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
        0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
        0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
        0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
        0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
        0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
        0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
        0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
        0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
        0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16,
    ])

    # Rijndael round constants
    RCON = [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36]

    def __init__(self, key: bytes):
        if len(key) not in (16, 24, 32):
            raise ValueError('Invalid key size')
        self.key = key
        self.Nk = len(key) // 4
        self.Nb = 4
        self.Nr = {16: 10, 24: 12, 32: 14}[len(key)]
        self.round_keys = self._key_expansion()

    def _rot_word(self, word):
        return word[1:] + word[:1]

    def _sub_word(self, word):
        return [self.SBOX[b] for b in word]

    def _key_expansion(self):
        w = []
        for i in range(self.Nk):
            w.append(list(self.key[4*i:4*(i+1)]))
        for i in range(self.Nk, self.Nb * (self.Nr + 1)):
            temp = w[-1]
            if i % self.Nk == 0:
                temp = self._sub_word(self._rot_word(temp))
                temp[0] ^= self.RCON[self.Nk - 1]
            elif self.Nk > 6 and i % self.Nk == 4:
                temp = self._sub_word(temp)
            w.append([w[i - self.Nk][j] ^ temp[j] for j in range(4)])
        return w

    def _sub_bytes(self, state):
        return [[self.SBOX[b] for b in row] for row in state]

    def _shift_rows(self, state):
        return [
            state[0],
            [state[1][1], state[1][2], state[1][3], state[1][0]],
            [state[2][2], state[2][3], state[2][0], state[2][1]],
            [state[3][3], state[3][0], state[3][1], state[3][2]],
        ]


    def _mix_columns(self, state):
        def gf_mul(a, b):
            """Galois Field multiplication for AES"""
            p = 0
            for _ in range(8):
                if b & 1:
                    p ^= a
                hi_bit_set = a & 0x80
                a = (a << 1) & 0xFF
                if hi_bit_set:
                    a ^= 0x1B  # AES irreducible polynomial
                b >>= 1
            return p

        def mix_column(col):
            a, b, c, d = col
            return [
                gf_mul(a, 2) ^ gf_mul(b, 3) ^ c ^ d,
                a ^ gf_mul(b, 2) ^ gf_mul(c, 3) ^ d,
                a ^ b ^ gf_mul(c, 2) ^ gf_mul(d, 3),
                gf_mul(a, 3) ^ b ^ c ^ gf_mul(d, 2),
            ]
        return [mix_column(state[i]) for i in range(4)]

    def _add_round_key(self, state, round_key):
        return [[state[i][j] ^ round_key[i][j] for j in range(4)] for i in range(4)]

    def _encrypt_block(self, block):
        if len(block) < 16:
            block = list(block) + [0] * (16 - len(block))
        state = [[block[4*j+i] for j in range(4)] for i in range(4)]
        state = self._add_round_key(state, self.round_keys[:4])

        for round_num in range(1, self.Nr):
            state = self._sub_bytes(state)
            state = self._shift_rows(state)
            state = self._mix_columns(state)
            state = self._add_round_key(state, self.round_keys[4*round_num:4*(round_num+1)])

        state = self._sub_bytes(state)
        state = self._shift_rows(state)
        state = self._add_round_key(state, self.round_keys[4*self.Nr:])

        return bytes(state[i][j] for j in range(4) for i in range(4))


def aes_ctr_encrypt(plaintext: bytes, key: bytes, nonce: bytes) -> bytes:
    aes = SimpleAES(key)
    counter = struct.unpack('>Q', nonce[:8])[0] & 0xFFFFFFFFFFFFFFFF
    result = bytearray()

    for i in range(0, len(plaintext), 16):
        counter_bytes = struct.pack('>Q', counter)
        keystream = aes._encrypt_block(list(counter_bytes))
        block = plaintext[i:i+16]
        keystream = keystream[:len(block)]
        encrypted_block = bytes(a ^ b for a, b in zip(block, keystream))
        result.extend(encrypted_block)
        counter += 1

    return bytes(result)


def aes_ctr_decrypt(ciphertext: bytes, key: bytes, nonce: bytes) -> bytes:
    return aes_ctr_encrypt(ciphertext, key, nonce)
