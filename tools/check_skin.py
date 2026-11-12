import json, struct

with open('MuGodot/assets/mu/Item/Bow07.glb', 'rb') as f:
    data = f.read()

chunk0_len, _ = struct.unpack_from('<II', data, 12)
gltf = json.loads(data[20:20+chunk0_len].decode('utf-8'))
mesh = gltf['meshes'][0]
prim = mesh['primitives'][0]
print("Attributes:", prim['attributes'])
skin = gltf['skins'][0]
print("Skin joints:", skin['joints'])
print("Inverse bind matrices accessor:", skin.get('inverseBindMatrices'))
