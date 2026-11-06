import numpy as np, json, math, io, sys, bmd
from PIL import Image
from convert import build_geometry, tex_png, C, S, TYPES
OUT='/mnt/user-data/outputs/MuGodot/assets/lorencia'
W,H=960,540
cx,cy=float(sys.argv[1]),float(sys.argv[2]); D=float(sys.argv[3]) if len(sys.argv)>3 else 13.0
z=np.load('terrain.npz'); hb=z['hb']; l1=z['l1'];l2=z['l2'];al=z['al'].astype(np.float32)/255;flag=z['flag'];final=z['final']
final=np.asarray(Image.open(OUT+'/terrain/terrain_light.png'),np.float32)/255
def hgt(x,y):
    x0=int(math.floor(x));y0=int(math.floor(y));fx=x-x0;fy=y-y0
    h=lambda a,b: hb[b&255,a&255]*0.015
    return (h(x0,y0)*(1-fx)+h(x0+1,y0)*fx)*(1-fy)+(h(x0,y0+1)*(1-fx)+h(x0+1,y0+1)*fx)*fy
target=np.array([cx+.5,hgt(cx+.5,cy+.5),-(cy+.5)])
cam=target+np.array([0.707*D, D-1.5, 0.469*D])
fwd=np.array([-0.530,-0.663,-0.530]); fwd/=np.linalg.norm(fwd)
up=np.array([-0.469,0.749,-0.469]); right=np.cross(fwd,up); right/=np.linalg.norm(right); up=np.cross(right,fwd)
f=1/math.tan(math.radians(30.5)/2)
def project(P):
    d=P-cam; xc=d@right; yc=d@up; zc=d@fwd
    sx=(xc/zc*f*(H/2))+W/2; sy=-(yc/zc*f*(H/2))+H/2
    return np.stack([sx,sy,zc],-1)
img=np.zeros((H,W,3),np.float32); zb=np.full((H,W),1e9,np.float32)
def raster(Pw, UV, tex, light, alpha_test, uvfn=None, cols=None, add=False):
    # Pw: (n,3,3) triangles world; UV: (n,3,2)
    sp=project(Pw.reshape(-1,3)).reshape(-1,3,3)
    th,tw=tex.shape[:2]
    for i in range(len(sp)):
        a,b,c=sp[i]
        if min(a[2],b[2],c[2])<0.3: continue
        x0=max(int(min(a[0],b[0],c[0])),0);x1=min(int(max(a[0],b[0],c[0]))+1,W)
        y0=max(int(min(a[1],b[1],c[1])),0);y1=min(int(max(a[1],b[1],c[1]))+1,H)
        if x0>=x1 or y0>=y1: continue
        area=(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
        if abs(area)<1e-9: continue
        ys,xs=np.mgrid[y0:y1,x0:x1]+0.5
        w0=((b[0]-xs)*(c[1]-ys)-(b[1]-ys)*(c[0]-xs))/area
        w1=((c[0]-xs)*(a[1]-ys)-(c[1]-ys)*(a[0]-xs))/area
        w2=1-w0-w1
        m=(w0>=0)&(w1>=0)&(w2>=0)
        if not m.any(): continue
        iz=w0/a[2]+w1/b[2]+w2/c[2]; zz=1/iz
        uv=(w0[...,None]*UV[i,0]/a[2]+w1[...,None]*UV[i,1]/b[2]+w2[...,None]*UV[i,2]/c[2])*zz[...,None]
        if uvfn: uv=uvfn(i,uv)
        tx=(np.mod(uv[...,0],1)*tw).astype(int)%tw; ty=(np.mod(uv[...,1],1)*th).astype(int)%th
        col=tex[ty,tx]
        if col.shape[-1]==4:
            if alpha_test: m&=col[...,3]>0.25
            col=col[...,:3]
        if cols is not None:
            li=(w0[...,None]*cols[i,0]/a[2]+w1[...,None]*cols[i,1]/b[2]+w2[...,None]*cols[i,2]/c[2])*zz[...,None]
            col=col*li
        else: col=col*light
        zsub=zb[y0:y1,x0:x1]; m&=zz<zsub
        if add: img[y0:y1,x0:x1][m]+=col[m]; return_=None
        else: zsub[m]=zz[m]; img[y0:y1,x0:x1][m]=col[m]
# terrain
atlas=np.asarray(Image.open(OUT+'/terrain/terrain_atlas.png'),np.float32)/255
meta=json.load(open(OUT+'/terrain/terrain_meta.json'))
R=26
tris=[];uvs=[];cl=[];info=[]
for ty in range(int(cy)-R,int(cy)+R):
    for tx in range(int(cx)-R,int(cx)+R):
        if tx<0 or ty<0 or tx>254 or ty>254: continue
        P=[np.array([x, hb[y,x]*0.015, -y]) for x,y in [(tx,ty),(tx+1,ty),(tx+1,ty+1),(tx,ty+1)]]
        U=[np.array([x,y],float) for x,y in [(tx,ty),(tx+1,ty),(tx+1,ty+1),(tx,ty+1)]]
        Lc=[np.concatenate([final[y,x],[al[y,x]]]) for x,y in [(tx,ty),(tx+1,ty),(tx+1,ty+1),(tx,ty+1)]]
        for t in [(0,1,2),(0,2,3)]:
            tris.append([P[k] for k in t]); uvs.append([U[k] for k in t]); cl.append([Lc[k] for k in t]); info.append((tx,ty))
tris=np.array(tris);uvs=np.array(uvs);cl=np.array(cl)
def tsample(layer,uv):
    s=meta['tile_scale'][layer]; cxp=(layer%4); cyp=layer//4
    u=np.mod(uv[...,0]*s,1); v=np.mod(uv[...,1]*s,1)
    px=((cxp+u)*256).astype(int).clip(0,1023); py=((cyp+v)*256).astype(int).clip(0,1023)
    return atlas[py,px]
# custom terrain raster w/ blending
sp=project(tris.reshape(-1,3)).reshape(-1,3,3)
for i in range(len(sp)):
    a,b,c=sp[i]
    if min(a[2],b[2],c[2])<0.3: continue
    x0=max(int(min(a[0],b[0],c[0])),0);x1=min(int(max(a[0],b[0],c[0]))+1,W)
    y0=max(int(min(a[1],b[1],c[1])),0);y1=min(int(max(a[1],b[1],c[1]))+1,H)
    if x0>=x1 or y0>=y1: continue
    area=(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    if abs(area)<1e-9: continue
    ys,xs=np.mgrid[y0:y1,x0:x1]+0.5
    w0=((b[0]-xs)*(c[1]-ys)-(b[1]-ys)*(c[0]-xs))/area; w1=((c[0]-xs)*(a[1]-ys)-(c[1]-ys)*(a[0]-xs))/area; w2=1-w0-w1
    m=(w0>=0)&(w1>=0)&(w2>=0)
    if not m.any(): continue
    zz=1/(w0/a[2]+w1/b[2]+w2/c[2])
    uv=(w0[...,None]*uvs[i,0]/a[2]+w1[...,None]*uvs[i,1]/b[2]+w2[...,None]*uvs[i,2]/c[2])*zz[...,None]
    li=(w0[...,None]*cl[i,0]/a[2]+w1[...,None]*cl[i,1]/b[2]+w2[...,None]*cl[i,2]/c[2])*zz[...,None]
    tx,ty=info[i]
    L1=int(l1[ty,tx]);L2=int(l2[ty,tx])
    if flag[ty,tx]: col=tsample(L2,uv)
    else:
        col=tsample(L1,uv)
        if L2!=255: col=col*(1-li[...,3:4])+tsample(L2,uv)*li[...,3:4]
    col=col*li[...,:3]
    zsub=zb[y0:y1,x0:x1]; m&=zz<zsub; zsub[m]=zz[m]; img[y0:y1,x0:x1][m]=col[m]
# objects
objs=json.load(open(OUT+'/lorencia_objects.json'))
cache={}
BLEND={117:4,118:8,119:2,122:4,105:3,52:1,98:2,90:1,150:1}
texcache={}
def get_tex(name):
    if name not in texcache:
        t=tex_png(name)
        texcache[name]=np.asarray(Image.open(io.BytesIO(t[0])).convert('RGBA'),np.float32)/255 if t else np.ones((2,2,4),np.float32)
    return texcache[name]
for o in objs:
    ox,oy,oz=o['o']
    if abs(ox-cx)>R or abs(-oz-cy)>R: continue
    if o['t'] in (130,131,132,133): continue
    mname=o['m']
    if mname not in cache:
        m=bmd.load('/mnt/user-data/uploads/MuMain/Client/Data/Object1/%s.bmd'%mname)
        mats=bmd.bone_matrices(m,0,0) if m.actions and m.actions[0]>0 else [np.eye(4)]*len(m.bones)
        cache[mname]=(m,build_geometry(m,mats,False))
    m,prims=cache[mname]
    B=np.array(o['b']).reshape(3,3).T; org=np.array(o['o'])
    lx,ly=ox,-oz
    lt=final[int(ly)&255,int(lx)&255]
    for mi,P,N,T,J,I in prims:
        Pw=(P@B.T+org)[I].reshape(-1,3,3); UV=T[I].reshape(-1,3,2)
        add = BLEND.get(o['t'],-99)==m.meshes[mi].tex_index
        raster(Pw,UV,get_tex(m.meshes[mi].texname),(np.ones(3)*0.7 if add else lt),not add,add=add)
Image.fromarray((img.clip(0,1)*255).astype(np.uint8)).save(sys.argv[4] if len(sys.argv)>4 else 'preview.png')
