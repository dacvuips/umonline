import os, sys
from PIL import Image

sys.path.append('E:/MuMain/MuGodot/tools')
from mu_convert_all import decode_ozt

out_dir = 'E:/MuMain/MuGodot/assets/mu/Player/inven_tex'
os.makedirs(out_dir, exist_ok=True)

files = [
    'InvenArmorMale40.OZT',
    'InvenArmorMale41.OZT',
    'InvenArmorMale42.OZT',
    'InvenArmorMale43.OZT',
    'InvenArmorMale44.OZT',
    'InvenArmorMale45.OZT',
    'InvenPantsMale40.OZT',
    'InvenPantsMale41.OZT',
    'InvenPantsMale42.OZT',
    'InvenPantsMale43.OZT',
    'InvenPantsMale44.OZT',
    'InvenPantsMale45.OZT',
    'Item312_Armoritem.OZT',
    'Item312_Pantitem.OZT',
    'SkinClass706_upperitem.OZT',
    'SkinClass706_loweritem.OZT'
]

for fname in files:
    src_path = os.path.join('E:/MuMain/Client/Data/Player', fname)
    if os.path.exists(src_path):
        data = open(src_path, 'rb').read()
        w, h, rgba, has_alpha = decode_ozt(data)
        im = Image.frombytes('RGBA', (w, h), rgba)
        out_name = os.path.splitext(fname)[0] + '.png'
        out_path = os.path.join(out_dir, out_name)
        im.save(out_path)
        print(f"Decoded {fname} -> {out_name} ({w}x{h})")
    else:
        print(f"Not found: {src_path}")
