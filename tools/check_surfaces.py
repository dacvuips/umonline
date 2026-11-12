import json, struct

with open('MuGodot/assets/mu/Item/Bow07.glb', 'rb') as f:
    data = f.read()

chunk0_len, _ = struct.unpack_from('<II', data, 12)
gltf = json.loads(data[20:20+chunk0_len].decode('utf-8'))

for i, prim in enumerate(gltf['meshes'][0]['primitives']):
    pos_idx = prim['attributes']['POSITION']
    pos_acc = gltf['accessors'][pos_idx]
    print(f"Surface {i}: count={pos_acc['count']}, min={pos_acc['min']}, max={pos_acc['max']}, material={prim.get('material')}")
