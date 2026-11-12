import zlib, struct

with open('MuGodot/assets/mu/icons/04_006.png', 'rb') as f:
    data = f.read()

# Simple raw decode of RGBA PNG
w, h = struct.unpack('>II', data[16:24])
idat = bytearray()
idx = 8
while idx < len(data):
    chunk_len, chunk_type = struct.unpack('>I4s', data[idx:idx+8])
    if chunk_type == b'IDAT':
        idat.extend(data[idx+8:idx+8+chunk_len])
    idx += 12 + chunk_len

decompressed = zlib.decompress(idat)
# Find bounding box of non-alpha-0 pixels
min_x, max_x = w, 0
min_y, max_y = h, 0
non_zero = 0

stride = 1 + w * 4
for y in range(h):
    row = decompressed[y*stride + 1 : (y+1)*stride]
    for x in range(w):
        a = row[x*4 + 3]
        if a > 10:
            min_x = min(min_x, x)
            max_x = max(max_x, x)
            min_y = min(min_y, y)
            max_y = max(max_y, y)
            non_zero += 1

print(f"Non-zero pixels: {non_zero}")
print(f"Bounding box: x=[{min_x}, {max_x}] (width {max_x - min_x + 1}), y=[{min_y}, {max_y}] (height {max_y - min_y + 1})")
