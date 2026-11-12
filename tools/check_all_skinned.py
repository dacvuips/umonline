import os, glob, struct, json

items = glob.glob('MuGodot/assets/mu/Item/*.glb')
skinned = []
for p in items:
    with open(p, 'rb') as f:
        f.seek(12)
        chunk0_len, _ = struct.unpack('<II', f.read(8))
        json_bytes = f.read(chunk0_len)
    gltf = json.loads(json_bytes.decode('utf-8'))
    if 'skins' in gltf and len(gltf['skins']) > 0:
        skinned.append(os.path.basename(p))

print(f"Total items: {len(items)}, Skinned items: {len(skinned)}")
print("Skinned items:", skinned)
