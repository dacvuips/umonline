import bmd, numpy as np, json, struct, math, os
from PIL import Image
from convert import decode_tex, OUT, TYPES, C, S
W1='/mnt/user-data/uploads/MuMain/Client/Data/World1'
T=OUT+'/terrain'; os.makedirs(T,exist_ok=True)
z=np.load('/tmp/claude-0/-home-claude/1d3f39cc-f992-51e3-b270-8ed98722b989/scratchpad/conv/terrain.npz')
l1,l2,al,hb,att,final,flag=[z[k] for k in ['l1','l2','al','hb','att','final','flag']]
Image.fromarray(np.stack([l1,l2,flag],-1).astype(np.uint8),'RGB').save(T+'/terrain_layers.png')
Image.fromarray((final*255+0.5).clip(0,255).astype(np.uint8),'RGB').save(T+'/terrain_light.png')
Image.fromarray(np.stack([hb,al,(att&255).astype(np.uint8)],-1).astype(np.uint8),'RGB').save(T+'/terrain_misc.png')
# tile atlas 4x4 of 256
tiles=['TileGrass01','TileGrass02','TileGround01','TileGround02','TileGround03','TileWater01','TileWood01','TileRock01','TileRock02','TileRock03','TileRock04','TileRock05','TileRock06','TileRock07']
atlas=Image.new('RGB',(1024,1024)); scales=[]
for i,n in enumerate(tiles):
    im,_=decode_tex(W1+'/'+n+'.OZJ'); w=im.size[0]; scales.append(64.0/w)
    im=im.resize((256,256),Image.NEAREST)
    atlas.paste(im,((i%4)*256,(i//4)*256))
atlas.save(T+'/terrain_atlas.png')
# grass atlas
g=Image.new('RGBA',(256,256),(0,0,0,0)); y=0; grass=[]
for n in ['TileGrass01','TileGrass02','TileGrass03']:
    im,_=decode_tex(W1+'/'+n+'.OZT'); g.paste(im,(0,y)); grass.append([y/256.0, im.size[1]/256.0, im.size[1]*2/100.0]); y+=im.size[1]
g.save(T+'/grass_atlas.png')
meta={'tile_scale':scales,'grass':grass,'height_scale':1.5/100.0}
json.dump(meta,open(T+'/terrain_meta.json','w'),indent=1)
print(meta)

# ---------- objects ----------
d=bmd.map_decrypt(open(W1+'/EncTerrain1.obj','rb').read())
n=struct.unpack_from('<h',d,2)[0]; p=4
def angle_matrix(a):
    a=[x*math.pi/180 for x in a]
    sy,cy=math.sin(a[2]),math.cos(a[2]); sp,cp=math.sin(a[1]),math.cos(a[1]); sr,cr=math.sin(a[0]),math.cos(a[0])
    return np.array([[cp*cy, sr*sp*cy+cr*-sy, cr*sp*cy+-sr*-sy],
                     [cp*sy, sr*sp*sy+cr*cy, cr*sp*sy+-sr*cy],
                     [-sp, sr*cp, cr*cp]])
objs=[]
for i in range(n):
    t=struct.unpack_from('<h',d,p)[0]; pos=np.array(struct.unpack_from('<3f',d,p+2)); ang=struct.unpack_from('<3f',d,p+14); s=struct.unpack_from('<f',d,p+26)[0]; p+=30
    if t not in TYPES: print('unknown type',t); continue
    R=C@angle_matrix(ang)@C.T*s
    o=C@pos*S
    objs.append({'t':t,'m':TYPES[t],'b':[round(float(x),5) for x in R.T.flatten()],'o':[round(float(x),4) for x in o],'s':round(s,4),'a':[round(x,2) for x in ang]})
json.dump(objs,open(OUT+'/lorencia_objects.json','w'),separators=(',',':'))
print(len(objs))
# ---------- collision (same format as before) ----------
grid=[[int(att[y,x]) for x in range(256)] for y in range(256)]
os.makedirs('/mnt/user-data/outputs/MuGodot/assets/maps',exist_ok=True)
json.dump({'width':256,'height':256,'grid':grid},open('/mnt/user-data/outputs/MuGodot/assets/maps/lorencia_collision.json','w'),separators=(',',':'))

# ---------- Ánh sáng động "tĩnh" của MU (AddTerrainLight mỗi frame) -> bake vào terrain_light ----------
# Đã hạ tông đỏ của lửa: dùng ánh sáng vàng cam dịu ấm thay vì đỏ gắt (0.85, 0.51, 0.34)
FIRE0={130:[(0,0,0)],80:[(90,-200,30),(90,200,30)],55:[(-150,-150,140),(150,-150,140)],50:[(0,0,200)],51:[(0,-30,60)],52:[(0,0,60)]}
def add_light(buf,xf,yf,light,R):
    xi,yi=int(xf),int(yf)
    for sy in range(yi-int(math.ceil(R)),yi+int(math.ceil(R))+1):
        for sx in range(xi-int(math.ceil(R)),xi+int(math.ceil(R))+1):
            dist=math.hypot(xf-sx,yf-sy)
            if dist<R:
                lf=((R-dist)/R)**1.3
                buf[sy&255,sx&255]+=np.array(light)*lf
dyn=np.zeros_like(final)
d=bmd.map_decrypt(open(W1+'/EncTerrain1.obj','rb').read()); p=4
fires_out=[]
for i in range(n):
    t=struct.unpack_from('<h',d,p)[0]; pos=np.array(struct.unpack_from('<3f',d,p+2)); ang=struct.unpack_from('<3f',d,p+14); p+=30
    if t in FIRE0:
        M=angle_matrix(ang)
        for off in FIRE0[t]:
            w=M@np.array(off,float)+pos
            add_light(dyn,w[0]/100,w[1]/100,(0.26,0.20,0.09),3.2)
            fwd=M@np.array([0,-1.0,0])  # hướng Velocity (0,-v,0) của hạt lửa
            fires_out.append({'p':[round(float(x),4) for x in C@w*S],'d':[round(float(x),4) for x in C@fwd]})
    elif t==90: add_light(dyn,pos[0]/100,pos[1]/100,(0.35,0.30,0.20),3.0)
    elif t==150: add_light(dyn,pos[0]/100,pos[1]/100,(0.25,0.18,0.08),2.0)
lit=np.clip(final+dyn,0,1)
Image.fromarray((lit*255+0.5).clip(0,255).astype(np.uint8),'RGB').save(T+'/terrain_light.png')
json.dump(fires_out,open(OUT+'/lorencia_fires.json','w'),separators=(',',':'))
print('fires',len(fires_out))
