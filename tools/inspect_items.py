import json, math, struct, os

def angle_matrix(a):
    r0 = math.radians(float(a[0]))
    r1 = math.radians(float(a[1]))
    r2 = math.radians(float(a[2]))
    sy, cy = math.sin(r2), math.cos(r2)
    sp, cp = math.sin(r1), math.cos(r1)
    sr, cr = math.sin(r0), math.cos(r0)
    return [[cp * cy, sr * sp * cy - cr * sy, cr * sp * cy + sr * sy],
            [cp * sy, sr * sp * sy + cr * cy, cr * sp * sy - sr * cy],
            [-sp, sr * cp, cr * cp]]

def basis(rot):
    r = angle_matrix(rot)
    ct = [[1, 0, 0], [0, 0, -1], [0, 1, 0]]
    m = []
    for i in range(3):
        row = []
        for j in range(3):
            v = sum(r[i][k] * ct[k][j] for k in range(3))
            row.append(v)
        m.append(row)
    return m

def parse_glb_positions(glb_path):
    if not os.path.exists(glb_path):
        return None
    with open(glb_path, 'rb') as f:
        data = f.read()
    magic, ver, length = struct.unpack_from('<4sII', data, 0)
    if magic != b'glTF':
        return None
    chunk0_len, chunk0_type = struct.unpack_from('<II', data, 12)
    json_bytes = data[20:20+chunk0_len]
    gltf = json.loads(json_bytes.decode('utf-8'))
    
    bin_offset = 20 + chunk0_len
    chunk1_len, chunk1_type = struct.unpack_from('<II', data, bin_offset)
    bin_bytes = data[bin_offset+8:bin_offset+8+chunk1_len]
    
    # Get bounding box of all POSITION accessors
    min_pt = [float('inf')]*3
    max_pt = [float('-inf')]*3
    
    for mesh in gltf.get('meshes', []):
        for prim in mesh.get('primitives', []):
            pos_acc_idx = prim.get('attributes', {}).get('POSITION')
            if pos_acc_idx is not None:
                acc = gltf['accessors'][pos_acc_idx]
                if 'min' in acc and 'max' in acc:
                    for i in range(3):
                        min_pt[i] = min(min_pt[i], acc['min'][i])
                        max_pt[i] = max(max_pt[i], acc['max'][i])
    return min_pt, max_pt

# Test bow 0..6
with open('MuGodot/assets/mu/catalog/Items/Models/Group04_Bow.json') as f:
    bow_models = json.load(f)['models']

for bm in bow_models:
    num = bm['number']
    inv = bm.get('inventory', {})
    rot = inv.get('rotation', [270.0, -10.0, 0.0])
    b = basis(rot)
    glb_name = os.path.basename(bm['file']).replace('.bmd', '.glb')
    glb_path = os.path.join('MuGodot/assets/mu/Item', glb_name)
    pts = parse_glb_positions(glb_path)
    if pts:
        pmin, pmax = pts
        # Compute transformed AABB (8 corners)
        corners = []
        for x in [pmin[0], pmax[0]]:
            for y in [pmin[1], pmax[1]]:
                for z in [pmin[2], pmax[2]]:
                    tx = b[0][0]*x + b[0][1]*y + b[0][2]*z
                    ty = b[1][0]*x + b[1][1]*y + b[1][2]*z
                    tz = b[2][0]*x + b[2][1]*y + b[2][2]*z
                    corners.append((tx, ty, tz))
        aabb_min = [min(c[i] for c in corners) for i in range(3)]
        aabb_max = [max(c[i] for c in corners) for i in range(3)]
        size = [aabb_max[i] - aabb_min[i] for i in range(3)]
        print(f"Bow {num:02d} ({glb_name}): rot={rot} => projected size=(X:{size[0]:.3f}, Y:{size[1]:.3f}, Z:{size[2]:.3f}) raw mesh size=({pmax[0]-pmin[0]:.3f}, {pmax[1]-pmin[1]:.3f}, {pmax[2]-pmin[2]:.3f})")
