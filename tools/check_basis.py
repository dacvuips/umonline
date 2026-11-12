import math

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

rot = [180, 270, 25]
b = basis(rot)
print("Basis matrix for [180, 270, 25]:")
for row in b:
    print([f"{v:+.4f}" for v in row])

# In Godot, Camera looks along -Z (or +Z in MuItemIcon? Wait, Camera3D looks along -Z!)
# An orthogonal camera looks down -Z towards origin, with +X right and +Y up!
# Let's project a vector (x, y, z) in Godot mesh space:
# v_world = Basis * v_mesh
# Camera sees: X_cam = v_world.x, Y_cam = v_world.y
print("\nTransformation of Godot mesh axes (x=thickness 0.095, y=height 2.708, z=curve 0.986):")
# Godot mesh X axis (1, 0, 0):
print("Mesh X (thickness) -> World:", [f"{b[i][0]:+.4f}" for i in range(3)])
# Godot mesh Y axis (0, 1, 0):
print("Mesh Y (MU -Y: curve) -> World:", [f"{b[i][1]:+.4f}" for i in range(3)])
# Godot mesh Z axis (0, 0, 1):
print("Mesh Z (MU +Z: length/height) -> World:", [f"{b[i][2]:+.4f}" for i in range(3)])
