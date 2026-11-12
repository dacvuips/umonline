#!/usr/bin/env python3
"""
mu_bmd14.py — Giải mã model BMD phiên bản 14 (0x0E) của client MU mùa sau (IGCN Season 9+).

Theo Source/src/source/Render/Models/BmdModulusCipher.cpp:
  payload = dữ liệu sau "BMD", byte phiên bản và int32 kích thước.
  1. payload[1] & 7 chọn thuật toán, khoá cố định "webzen#@!01webzen#@!01webzen#@!0", giải mã vài khối 1 KB
     (ở offset 2, cuối payload, và giữa payload nếu lớn).
  2. payload[2..34) là khoá của thuật toán thứ 2 (payload[0] & 7), giải mã toàn bộ từ offset 34 (ECB, phần
     đuôi lẻ giữ nguyên). Sau đó payload[34..] là thân BMD giống phiên bản 10.
Thuật toán (Crypto++, độ dài khoá mặc định): 0 TEA, 1 3-Way, 2 CAST-128, 3 RC5, 4 RC6, 5 MARS, 6 IDEA, 7 GOST.
Cài đặt lại phần giải mã của Crypto++ bằng Python (CAST-128 dùng pycryptodome nếu có).
"""
import struct

M32 = 0xFFFFFFFF
FIRST_KEY = b"webzen#@!01webzen#@!01webzen#@!0"
BODY_OFFSET = 34


def rotl(x, n):
    n &= 31
    return ((x << n) | (x >> (32 - n))) & M32 if n else x


def rotr(x, n):
    n &= 31
    return ((x >> n) | (x << (32 - n))) & M32 if n else x


# ----------------------------------------------------------------------------- TEA (big-endian, 32 vòng)
class TEA:
    block = 8

    def __init__(self, key):
        self.k = struct.unpack('>4I', key[:16])

    def decrypt(self, b):
        y, z = struct.unpack('>2I', b)
        k0, k1, k2, k3 = self.k
        d = 0x9E3779B9
        s = (32 * d) & M32
        while s:
            z = (z - ((((y << 4) + k2) ^ (y + s) ^ ((y >> 5) + k3)) & M32)) & M32
            y = (y - ((((z << 4) + k0) ^ (z + s) ^ ((z >> 5) + k1)) & M32)) & M32
            s = (s - d) & M32
        return struct.pack('>2I', y, z)


# ----------------------------------------------------------------------------- 3-Way (11 vòng)
def _rev_bits(a):
    a = ((a & 0xAAAAAAAA) >> 1) | ((a & 0x55555555) << 1)
    a = ((a & 0xCCCCCCCC) >> 2) | ((a & 0x33333333) << 2)
    return (((a & 0xF0F0F0F0) >> 4) | ((a & 0x0F0F0F0F) << 4)) & M32


def _mu(a0, a1, a2):
    return _rev_bits(a2), _rev_bits(a1), _rev_bits(a0)


def _theta(a0, a1, a2):
    c = a0 ^ a1 ^ a2
    c = rotl(c, 16) ^ rotl(c, 8)
    b0 = ((a0 << 24) ^ (a2 >> 8) ^ (a1 << 8) ^ (a0 >> 24)) & M32
    b1 = ((a1 << 24) ^ (a0 >> 8) ^ (a2 << 8) ^ (a1 >> 24)) & M32
    return a0 ^ c ^ b0, a1 ^ c ^ b1, (a2 ^ c ^ (b0 >> 16) ^ (b1 << 16)) & M32


def _pgp(a0, a1, a2):
    b2 = rotl(a2, 1)
    b0 = rotl(a0, 22)
    a0 = rotl(b0 ^ (a1 | (~b2 & M32)), 1)
    a2 = rotl(b2 ^ (b0 | (~a1 & M32)), 22)
    a1 ^= (b2 | (~b0 & M32))
    return a0, a1 & M32, a2


def _bswap(x):
    return struct.unpack('<I', struct.pack('>I', x))[0]


class ThreeWay:
    block = 12

    def __init__(self, key):
        k = struct.unpack('>3I', key[:12])
        k = _mu(*_theta(*k))
        self.k = [_bswap(x) for x in k]

    def decrypt(self, b):
        a0, a1, a2 = struct.unpack('<3I', b)
        k0, k1, k2 = self.k
        rc = 0xB1B1
        a0, a1, a2 = _mu(a0, a1, a2)
        for _ in range(11):
            a0 ^= k0 ^ ((rc << 16) & M32)
            a1 ^= k1
            a2 ^= k2 ^ rc
            a0, a1, a2 = _pgp(*_theta(a0, a1, a2))
            rc <<= 1
            if rc & 0x10000:
                rc ^= 0x11011
        a0 ^= k0 ^ ((rc << 16) & M32)
        a1 ^= k1
        a2 ^= k2 ^ rc
        a0, a1, a2 = _mu(*_theta(a0, a1, a2))
        return struct.pack('<3I', a0, a1, a2)


# ----------------------------------------------------------------------------- CAST-128 (khoá 16 byte)
class CAST128:
    block = 8

    def __init__(self, key):
        from Crypto.Cipher import CAST   # pycryptodome
        self.c = CAST.new(key[:16], CAST.MODE_ECB)

    def decrypt(self, b):
        return self.c.decrypt(b)

    def decrypt_many(self, data):
        return self.c.decrypt(data)


# ----------------------------------------------------------------------------- RC5 / RC6 (little-endian)
def _rc_schedule(key, size):
    P, Q = 0xB7E15163, 0x9E3779B9
    c = max((len(key) + 3) // 4, 1)
    L = list(struct.unpack('<%dI' % c, key.ljust(c * 4, b'\0')))
    S = [(P + i * Q) & M32 for i in range(size)]
    a = b = 0
    for h in range(3 * max(size, c)):
        a = S[h % size] = rotl((S[h % size] + a + b) & M32, 3)
        b = L[h % c] = rotl((L[h % c] + a + b) & M32, (a + b) & 31)
    return S


class RC5:
    block = 8

    def __init__(self, key, rounds=16):
        self.r = rounds
        self.S = _rc_schedule(key[:16], 2 * (rounds + 1))

    def decrypt(self, blk):
        a, b = struct.unpack('<2I', blk)
        S = self.S
        for i in range(self.r, 0, -1):
            b = rotr((b - S[2 * i + 1]) & M32, a) ^ a
            a = rotr((a - S[2 * i]) & M32, b) ^ b
        return struct.pack('<2I', (a - S[0]) & M32, (b - S[1]) & M32)


class RC6:
    block = 16

    def __init__(self, key, rounds=20):
        self.r = rounds
        self.S = _rc_schedule(key[:16], 2 * (rounds + 2))

    def decrypt(self, blk):
        a, b, c, d = struct.unpack('<4I', blk)
        S = self.S
        n = len(S)
        c = (c - S[n - 1]) & M32
        a = (a - S[n - 2]) & M32
        p = n - 2
        for _ in range(self.r):
            p -= 2
            a, b, c, d = d, a, b, c
            u = rotl((d * (2 * d + 1)) & M32, 5)
            t = rotl((b * (2 * b + 1)) & M32, 5)
            c = rotr((c - S[p + 1]) & M32, t) ^ u
            a = rotr((a - S[p]) & M32, u) ^ t
        return struct.pack('<4I', a, (b - S[0]) & M32, c, (d - S[1]) & M32)


# ----------------------------------------------------------------------------- MARS (khoá 16 byte)
# S-box 512 từ của MARS (Crypto++ marss.cpp)
MARS_SBOX = [
    0x09d0c479, 0x28c8ffe0, 0x84aa6c39, 0x9dad7287, 0x7dff9be3, 0xd4268361,
    0xc96da1d4, 0x7974cc93, 0x85d0582e, 0x2a4b5705, 0x1ca16a62, 0xc3bd279d,
    0x0f1f25e5, 0x5160372f, 0xc695c1fb, 0x4d7ff1e4, 0xae5f6bf4, 0x0d72ee46,
    0xff23de8a, 0xb1cf8e83, 0xf14902e2, 0x3e981e42, 0x8bf53eb6, 0x7f4bf8ac,
    0x83631f83, 0x25970205, 0x76afe784, 0x3a7931d4, 0x4f846450, 0x5c64c3f6,
    0x210a5f18, 0xc6986a26, 0x28f4e826, 0x3a60a81c, 0xd340a664, 0x7ea820c4,
    0x526687c5, 0x7eddd12b, 0x32a11d1d, 0x9c9ef086, 0x80f6e831, 0xab6f04ad,
    0x56fb9b53, 0x8b2e095c, 0xb68556ae, 0xd2250b0d, 0x294a7721, 0xe21fb253,
    0xae136749, 0xe82aae86, 0x93365104, 0x99404a66, 0x78a784dc, 0xb69ba84b,
    0x04046793, 0x23db5c1e, 0x46cae1d6, 0x2fe28134, 0x5a223942, 0x1863cd5b,
    0xc190c6e3, 0x07dfb846, 0x6eb88816, 0x2d0dcc4a, 0xa4ccae59, 0x3798670d,
    0xcbfa9493, 0x4f481d45, 0xeafc8ca8, 0xdb1129d6, 0xb0449e20, 0x0f5407fb,
    0x6167d9a8, 0xd1f45763, 0x4daa96c3, 0x3bec5958, 0xababa014, 0xb6ccd201,
    0x38d6279f, 0x02682215, 0x8f376cd5, 0x092c237e, 0xbfc56593, 0x32889d2c,
    0x854b3e95, 0x05bb9b43, 0x7dcd5dcd, 0xa02e926c, 0xfae527e5, 0x36a1c330,
    0x3412e1ae, 0xf257f462, 0x3c4f1d71, 0x30a2e809, 0x68e5f551, 0x9c61ba44,
    0x5ded0ab8, 0x75ce09c8, 0x9654f93e, 0x698c0cca, 0x243cb3e4, 0x2b062b97,
    0x0f3b8d9e, 0x00e050df, 0xfc5d6166, 0xe35f9288, 0xc079550d, 0x0591aee8,
    0x8e531e74, 0x75fe3578, 0x2f6d829a, 0xf60b21ae, 0x95e8eb8d, 0x6699486b,
    0x901d7d9b, 0xfd6d6e31, 0x1090acef, 0xe0670dd8, 0xdab2e692, 0xcd6d4365,
    0xe5393514, 0x3af345f0, 0x6241fc4d, 0x460da3a3, 0x7bcf3729, 0x8bf1d1e0,
    0x14aac070, 0x1587ed55, 0x3afd7d3e, 0xd2f29e01, 0x29a9d1f6, 0xefb10c53,
    0xcf3b870f, 0xb414935c, 0x664465ed, 0x024acac7, 0x59a744c1, 0x1d2936a7,
    0xdc580aa6, 0xcf574ca8, 0x040a7a10, 0x6cd81807, 0x8a98be4c, 0xaccea063,
    0xc33e92b5, 0xd1e0e03d, 0xb322517e, 0x2092bd13, 0x386b2c4a, 0x52e8dd58,
    0x58656dfb, 0x50820371, 0x41811896, 0xe337ef7e, 0xd39fb119, 0xc97f0df6,
    0x68fea01b, 0xa150a6e5, 0x55258962, 0xeb6ff41b, 0xd7c9cd7a, 0xa619cd9e,
    0xbcf09576, 0x2672c073, 0xf003fb3c, 0x4ab7a50b, 0x1484126a, 0x487ba9b1,
    0xa64fc9c6, 0xf6957d49, 0x38b06a75, 0xdd805fcd, 0x63d094cf, 0xf51c999e,
    0x1aa4d343, 0xb8495294, 0xce9f8e99, 0xbffcd770, 0xc7c275cc, 0x378453a7,
    0x7b21be33, 0x397f41bd, 0x4e94d131, 0x92cc1f98, 0x5915ea51, 0x99f861b7,
    0xc9980a88, 0x1d74fd5f, 0xb0a495f8, 0x614deed0, 0xb5778eea, 0x5941792d,
    0xfa90c1f8, 0x33f824b4, 0xc4965372, 0x3ff6d550, 0x4ca5fec0, 0x8630e964,
    0x5b3fbbd6, 0x7da26a48, 0xb203231a, 0x04297514, 0x2d639306, 0x2eb13149,
    0x16a45272, 0x532459a0, 0x8e5f4872, 0xf966c7d9, 0x07128dc0, 0x0d44db62,
    0xafc8d52d, 0x06316131, 0xd838e7ce, 0x1bc41d00, 0x3a2e8c0f, 0xea83837e,
    0xb984737d, 0x13ba4891, 0xc4f8b949, 0xa6d6acb3, 0xa215cdce, 0x8359838b,
    0x6bd1aa31, 0xf579dd52, 0x21b93f93, 0xf5176781, 0x187dfdde, 0xe94aeb76,
    0x2b38fd54, 0x431de1da, 0xab394825, 0x9ad3048f, 0xdfea32aa, 0x659473e3,
    0x623f7863, 0xf3346c59, 0xab3ab685, 0x3346a90b, 0x6b56443e, 0xc6de01f8,
    0x8d421fc0, 0x9b0ed10c, 0x88f1a1e9, 0x54c1f029, 0x7dead57b, 0x8d7ba426,
    0x4cf5178a, 0x551a7cca, 0x1a9a5f08, 0xfcd651b9, 0x25605182, 0xe11fc6c3,
    0xb6fd9676, 0x337b3027, 0xb7c8eb14, 0x9e5fd030, 0x6b57e354, 0xad913cf7,
    0x7e16688d, 0x58872a69, 0x2c2fc7df, 0xe389ccc6, 0x30738df1, 0x0824a734,
    0xe1797a8b, 0xa4a8d57b, 0x5b5d193b, 0xc8a8309b, 0x73f9a978, 0x73398d32,
    0x0f59573e, 0xe9df2b03, 0xe8a5b6c8, 0x848d0704, 0x98df93c2, 0x720a1dc3,
    0x684f259a, 0x943ba848, 0xa6370152, 0x863b5ea3, 0xd17b978b, 0x6d9b58ef,
    0x0a700dd4, 0xa73d36bf, 0x8e6a0829, 0x8695bc14, 0xe35b3447, 0x933ac568,
    0x8894b022, 0x2f511c27, 0xddfbcc3c, 0x006662b6, 0x117c83fe, 0x4e12b414,
    0xc2bca766, 0x3a2fec10, 0xf4562420, 0x55792e2a, 0x46f5d857, 0xceda25ce,
    0xc3601d3b, 0x6c00ab46, 0xefac9c28, 0xb3c35047, 0x611dfee3, 0x257c3207,
    0xfdd58482, 0x3b14d84f, 0x23becb64, 0xa075f3a3, 0x088f8ead, 0x07adf158,
    0x7796943c, 0xfacabf3d, 0xc09730cd, 0xf7679969, 0xda44e9ed, 0x2c854c12,
    0x35935fa3, 0x2f057d9f, 0x690624f8, 0x1cb0bafd, 0x7b0dbdc6, 0x810f23bb,
    0xfa929a1a, 0x6d969a17, 0x6742979b, 0x74ac7d05, 0x010e65c4, 0x86a3d963,
    0xf907b5a0, 0xd0042bd3, 0x158d7d03, 0x287a8255, 0xbba8366f, 0x096edc33,
    0x21916a7b, 0x77b56b86, 0x951622f9, 0xa6c5e650, 0x8cea17d1, 0xcd8c62bc,
    0xa3d63433, 0x358a68fd, 0x0f9b9d3c, 0xd6aa295b, 0xfe33384a, 0xc000738e,
    0xcd67eb2f, 0xe2eb6dc2, 0x97338b02, 0x06c9f246, 0x419cf1ad, 0x2b83c045,
    0x3723f18a, 0xcb5b3089, 0x160bead7, 0x5d494656, 0x35f8a74b, 0x1e4e6c9e,
    0x000399bd, 0x67466880, 0xb4174831, 0xacf423b2, 0xca815ab3, 0x5a6395e7,
    0x302a67c5, 0x8bdb446b, 0x108f8fa4, 0x10223eda, 0x92b8b48b, 0x7f38d0ee,
    0xab2701d4, 0x0262d415, 0xaf224a30, 0xb3d88aba, 0xf8b2c3af, 0xdaf7ef70,
    0xcc97d3b7, 0xe9614b6c, 0x2baebff4, 0x70f687cf, 0x386c9156, 0xce092ee5,
    0x01e87da6, 0x6ce91e6a, 0xbb7bcc84, 0xc7922c20, 0x9d3b71fd, 0x060e41c6,
    0xd7590f15, 0x4e03bb47, 0x183c198e, 0x63eeb240, 0x2ddbf49a, 0x6d5cba54,
    0x923750af, 0xf9e14236, 0x7838162b, 0x59726c72, 0x81b66760, 0xbb2926c1,
    0x48a0ce0d, 0xa6c0496d, 0xad43507b, 0x718d496a, 0x9df057af, 0x44b1bde6,
    0x054356dc, 0xde7ced35, 0xd51a138b, 0x62088cc9, 0x35830311, 0xc96efca2,
    0x686f86ec, 0x8e77cb68, 0x63e1d6b8, 0xc80f9778, 0x79c491fd, 0x1b4c67f2,
    0x72698d7d, 0x5e368c31, 0xf7d95e2e, 0xa1d3493f, 0xdcd9433e, 0x896f1552,
    0x4bc4ca7a, 0xa6d1baf4, 0xa5a96dcc, 0x0bef8b46, 0xa169fda7, 0x74df40b7,
    0x4e208804, 0x9a756607, 0x038e87c8, 0x20211e44, 0x8b7ad4bf, 0xc6403f35,
    0x1848e36d, 0x80bdb038, 0x1e62891c, 0x643d2107, 0xbf04d6f8, 0x21092c8c,
    0xf644f389, 0x0778404e, 0x7b78adb8, 0xa2c52d53, 0x42157abe, 0xa2253e2e,
    0x7bf3f4ae, 0x80f594f9, 0x953194e7, 0x77eb92ed, 0xb3816930, 0xda8d9336,
    0xbf447469, 0xf26d9483, 0xee6faed5, 0x71371235, 0xde425f73, 0xb4e59f43,
    0x7dbe2d4e, 0x2d37b185, 0x49dc9a63, 0x98c39d98, 0x1301c9a2, 0x389b1bbf,
    0x0c18588d, 0xa421c1ba, 0x7aa3865c, 0x71e08558, 0x3c5cfcaa, 0x7d239ca4,
    0x0297d9dd, 0xd7dc2830, 0x4b37802b, 0x7428ab54, 0xaeee0347, 0x4b3fbb85,
    0x692f2f08, 0x134e578e, 0x36d9e0bf, 0xae8b5fcf, 0xedb93ecf, 0x2b27248e,
    0x170eb1ef, 0x7dc57fd6, 0x1e760f16, 0xb1136601, 0x864e1b9b, 0xd7ea7319,
    0x3ab871bd, 0xcfa4d76f, 0xe31bd782, 0x0dbeb469, 0xabb96061, 0x5370f85d,
    0xffb07e37, 0xda30d0fb, 0xebc977b6, 0x0b98b40f, 0x3a4d0fe6, 0xdf4fc26b,
    0x159cf22a, 0xc298d6e2, 0x2b78ef6a, 0x61a94ac0, 0xab561187, 0x14eea0f0,
    0xdf0d4164, 0x19af70ee,
]


class MARS:
    block = 16

    def __init__(self, key):
        key = key[:16]
        Sb = MARS_SBOX
        T = list(struct.unpack('<4I', key)) + [0] * 11
        T[len(key) // 4] = len(key) // 4
        K = [0] * 40
        for j in range(4):
            for i in range(15):
                T[i] = (T[i] ^ rotl(T[(i + 8) % 15] ^ T[(i + 13) % 15], 3) ^ (4 * i + j)) & M32
            for _ in range(4):
                for i in range(15):
                    T[i] = rotl((T[i] + Sb[T[(i + 14) % 15] % 512]) & M32, 9)
            for i in range(10):
                K[10 * j + i] = T[4 * i % 15]
        for i in range(5, 37, 2):
            w = K[i] | 3
            m = (~w ^ (w << 1)) & (~w ^ (w >> 1)) & 0x7FFFFFFE
            m &= m >> 1
            m &= m >> 2
            m &= m >> 4
            m |= m << 1
            m |= m << 2
            m |= m << 4
            m &= 0x7FFFFFFC
            w ^= rotl(Sb[265 + (K[i] & 3)], K[i - 1]) & m
            K[i] = w & M32
        self.k = K

    def decrypt(self, blk):
        Sb = MARS_SBOX
        k = self.k
        d, c, b, a = struct.unpack('<4I', blk)
        d = (d + k[36]) & M32
        c = (c + k[37]) & M32
        b = (b + k[38]) & M32
        a = (a + k[39]) & M32
        for i in range(8):
            b = ((b ^ Sb[a & 0xFF]) + Sb[((a >> 8) & 0xFF) + 256]) & M32
            c = (c + Sb[(a >> 16) & 0xFF]) & M32
            a = rotr(a, 24)
            d ^= Sb[(a & 0xFF) + 256]
            if i % 4 == 0:
                a = (a + d) & M32
            elif i % 4 == 1:
                a = (a + b) & M32
            a, b, c, d = b, c, d, a
        for i in range(16):
            t = rotr(a, 13)
            r = rotl((a * k[35 - 2 * i]) & M32, 10)
            m = (t + k[34 - 2 * i]) & M32
            l = rotl(Sb[m & 0x1FF] ^ rotr(r, 5) ^ r, r)
            c = (c - rotl(m, rotr(r, 5))) & M32
            if i < 8:
                b = (b - l) & M32
                d ^= r
            else:
                d = (d - l) & M32
                b ^= r
            a, b, c, d = b, c, d, t
        for i in range(8):
            if i % 4 == 2:
                a = (a - d) & M32
            elif i % 4 == 3:
                a = (a - b) & M32
            b ^= Sb[(a & 0xFF) + 256]
            c = (c - Sb[(a >> 24) & 0xFF]) & M32
            t = rotl(a, 24)
            d = ((d - Sb[((a >> 16) & 0xFF) + 256]) & M32) ^ Sb[t & 0xFF]
            a, b, c, d = b, c, d, t
        d = (d - k[0]) & M32
        c = (c - k[1]) & M32
        b = (b - k[2]) & M32
        a = (a - k[3]) & M32
        return struct.pack('<4I', d, c, b, a)


# ----------------------------------------------------------------------------- IDEA (8 vòng)
def _imul(a, b):
    a &= 0xFFFF
    b &= 0xFFFF
    if a == 0:
        a = 0x10000
    if b == 0:
        b = 0x10000
    return (a * b % 0x10001) & 0xFFFF


def _iinv(x):
    if x <= 1:
        return x
    return pow(x, 0xFFFF, 0x10001) & 0xFFFF


class IDEA:
    block = 8

    def __init__(self, key):
        Z = list(struct.unpack('>8H', key[:16])) + [0] * 44
        for i in range(8, 52):
            j = (i // 8) * 8 - 8
            Z[i] = ((Z[j + (i + 1) % 8] << 9) | (Z[j + (i + 2) % 8] >> 7)) & 0xFFFF
        R = 8
        D = [0] * 52
        for i in range(R):
            D[i * 6 + 0] = _iinv(Z[(R - i) * 6 + 0])
            D[i * 6 + 1] = (-Z[(R - i) * 6 + 1 + (i > 0)]) & 0xFFFF
            D[i * 6 + 2] = (-Z[(R - i) * 6 + 2 - (i > 0)]) & 0xFFFF
            D[i * 6 + 3] = _iinv(Z[(R - i) * 6 + 3])
            D[i * 6 + 4] = Z[(R - 1 - i) * 6 + 4]
            D[i * 6 + 5] = Z[(R - 1 - i) * 6 + 5]
        D[48] = _iinv(Z[0])
        D[49] = (-Z[1]) & 0xFFFF
        D[50] = (-Z[2]) & 0xFFFF
        D[51] = _iinv(Z[3])
        self.k = D

    def decrypt(self, blk):
        x0, x1, x2, x3 = struct.unpack('>4H', blk)
        k = self.k
        for i in range(8):
            x0 = _imul(x0, k[i * 6])
            x1 = (x1 + k[i * 6 + 1]) & 0xFFFF
            x2 = (x2 + k[i * 6 + 2]) & 0xFFFF
            x3 = _imul(x3, k[i * 6 + 3])
            t0 = _imul(x0 ^ x2, k[i * 6 + 4])
            t1 = _imul((t0 + (x1 ^ x3)) & 0xFFFF, k[i * 6 + 5])
            t0 = (t0 + t1) & 0xFFFF
            x0 ^= t1
            x3 ^= t0
            t0 ^= x1
            x1 = x2 ^ t1
            x2 = t0
        x0 = _imul(x0, k[48])
        x2 = (x2 + k[49]) & 0xFFFF
        x1 = (x1 + k[50]) & 0xFFFF
        x3 = _imul(x3, k[51])
        return struct.pack('>4H', x0, x2, x1, x3)


# ----------------------------------------------------------------------------- GOST (khoá 32 byte)
_GOST_SBOX = [
    [4, 10, 9, 2, 13, 8, 0, 14, 6, 11, 1, 12, 7, 15, 5, 3],
    [14, 11, 4, 12, 6, 13, 15, 10, 2, 3, 8, 1, 0, 7, 5, 9],
    [5, 8, 1, 13, 10, 3, 4, 2, 14, 15, 12, 7, 6, 0, 9, 11],
    [7, 13, 10, 1, 0, 8, 9, 15, 14, 4, 6, 12, 11, 2, 5, 3],
    [6, 12, 7, 1, 5, 15, 13, 8, 4, 10, 9, 14, 0, 3, 11, 2],
    [4, 11, 10, 0, 7, 2, 1, 13, 3, 6, 8, 5, 9, 12, 15, 14],
    [13, 11, 4, 1, 3, 15, 5, 9, 0, 10, 14, 7, 6, 8, 2, 12],
    [1, 15, 13, 0, 5, 7, 10, 4, 9, 2, 3, 14, 6, 11, 8, 12]]
_GOST_T = [[rotl(_GOST_SBOX[2 * i][j % 16] | (_GOST_SBOX[2 * i + 1][j // 16] << 4), 11 + 8 * i) for j in range(256)]
           for i in range(4)]


class GOST:
    block = 8

    def __init__(self, key):
        self.k = struct.unpack('<8I', key[:32])

    def decrypt(self, blk):
        T0, T1, T2, T3 = _GOST_T
        k = self.k
        n1, n2 = struct.unpack('<2I', blk)

        def f(x):
            x &= M32
            return T3[x >> 24] ^ T2[(x >> 16) & 0xFF] ^ T1[(x >> 8) & 0xFF] ^ T0[x & 0xFF]
        for i in range(8):
            if i % 2 == 0:
                n2 ^= f(n1 + k[i])
            else:
                n1 ^= f(n2 + k[i])
        for _ in range(3):
            for i in range(8):
                if i % 2 == 0:
                    n2 ^= f(n1 + k[7 - i])
                else:
                    n1 ^= f(n2 + k[7 - i])
        return struct.pack('<2I', n2, n1)


CIPHERS = [TEA, ThreeWay, CAST128, RC5, RC6, MARS, IDEA, GOST]


def _decrypt_range(cipher, buf, start, length):
    bs = cipher.block
    whole = length - length % bs
    if whole <= 0:
        return
    if hasattr(cipher, 'decrypt_many'):
        buf[start:start + whole] = cipher.decrypt_many(bytes(buf[start:start + whole]))
        return
    dec = cipher.decrypt
    for off in range(start, start + whole, bs):
        buf[off:off + bs] = dec(bytes(buf[off:off + bs]))


def decrypt_payload(payload):
    """Giải mã payload v14. Trả về thân BMD (từ offset 34) — đọc như BMD phiên bản 10."""
    buf = bytearray(payload)
    size = len(buf)
    if size < BODY_OFFSET + 38:
        raise ValueError('payload BMD v14 quá ngắn')
    c1 = CIPHERS[buf[1] & 7](FIRST_KEY)
    data_size = size - BODY_OFFSET
    chunk = 1024 - 1024 % c1.block
    if data_size > 4 * chunk:
        _decrypt_range(c1, buf, 2 + data_size // 2, chunk)
    if data_size > chunk:
        _decrypt_range(c1, buf, size - chunk, chunk)
        _decrypt_range(c1, buf, 2, chunk)
    c2 = CIPHERS[buf[0] & 7](bytes(buf[2:BODY_OFFSET]))
    _decrypt_range(c2, buf, BODY_OFFSET, size - BODY_OFFSET)
    return bytes(buf[BODY_OFFSET:])


def to_v10(data):
    """File BMD v14 -> bytes BMD v10 (b'BMD' + 0x0A + thân)."""
    if data[:3] != b'BMD' or data[3] != 14:
        raise ValueError('không phải BMD v14')
    n = struct.unpack_from('<i', data, 4)[0]
    return b'BMD\x0a' + decrypt_payload(data[8:8 + n])


if __name__ == '__main__':
    import sys
    import os
    for p in sys.argv[1:]:
        try:
            body = to_v10(open(p, 'rb').read())
            name = body[4:36].split(b'\0')[0]
            nm, nb, na = struct.unpack_from('<hhh', body, 36)
            print('%s: alg=%s name=%r meshes=%d bones=%d actions=%d' % (
                os.path.basename(p), open(p, 'rb').read(10)[8:10].hex(), name, nm, nb, na))
        except Exception as e:
            print('%s: LỖI %s' % (os.path.basename(p), e))
