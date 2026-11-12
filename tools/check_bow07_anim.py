import json, struct

with open('MuGodot/assets/mu/Item/Bow07.glb', 'rb') as f:
    data = f.read()
magic, ver, length = struct.unpack_from('<4sII', data, 0)
chunk0_len, chunk0_type = struct.unpack_from('<II', data, 12)
json_bytes = data[20:20+chunk0_len]
gltf = json.loads(json_bytes.decode('utf-8'))
for anim in gltf.get('animations', []):
    print("Anim name:", anim.get('name'))
    print("Channels:", len(anim.get('channels', [])))
