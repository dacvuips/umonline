import struct

with open('MuGodot/assets/mu/icons/04_006.png', 'rb') as f:
    data = f.read()

# PNG dimensions: bytes 16..24
w, h = struct.unpack('>II', data[16:24])
print(f"04_006.png size: {w}x{h}")
