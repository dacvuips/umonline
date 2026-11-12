import sys
sys.path.insert(0, 'MuGodot/tools')
import mu_convert_all

bmd = mu_convert_all.load_bmd('Client/Data/Item/Bow07.bmd')
for i, m in enumerate(bmd.meshes):
    xs = [v[1][0] for v in m.v]
    ys = [v[1][1] for v in m.v]
    zs = [v[1][2] for v in m.v]
    print(f"Mesh {i} MU coords: X=[{min(xs):.1f}, {max(xs):.1f}], Y=[{min(ys):.1f}, {max(ys):.1f}], Z=[{min(zs):.1f}, {max(zs):.1f}]")
