import json

with open('E:/MuMain/MuGodot/assets/mu/Player/HelmMale02.glb', 'rb') as f:
    data = f.read()

json_len = int.from_bytes(data[12:16], 'little')
gltf = json.loads(data[20:20+json_len].decode('utf-8'))
for i, mat in enumerate(gltf.get('materials', [])):
    print(i, 'material name:', mat.get('name'))
for i, img in enumerate(gltf.get('images', [])):
    print(i, 'image uri:', img.get('uri'))
