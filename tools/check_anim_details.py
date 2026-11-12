import json, struct

with open('MuGodot/assets/mu/Item/Bow07.glb', 'rb') as f:
    data = f.read()

chunk0_len, _ = struct.unpack_from('<II', data, 12)
gltf = json.loads(data[20:20+chunk0_len].decode('utf-8'))

bin_offset = 20 + chunk0_len + 8

print("Animations:")
for a in gltf.get('animations', []):
    print(f"Animation: {a.get('name')}")
    for ch in a.get('channels', []):
        target = ch['target']
        node_idx = target['node']
        node_name = gltf['nodes'][node_idx].get('name')
        path = target['path']
        print(f"  Channel target: node {node_idx} ({node_name}), path={path}")
