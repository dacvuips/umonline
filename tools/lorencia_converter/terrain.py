import bmd, numpy as np, io, os, json
from PIL import Image
from convert import decode_tex, OUT
W1='/mnt/user-data/uploads/MuMain/Client/Data/World1'
T=OUT+'/terrain'
# --- mapping
d=bmd.map_decrypt(open(W1+'/EncTerrain1.map','rb').read())
print('map ver',d[0],'num',d[1],len(d))
l1=np.frombuffer(d,np.uint8,65536,2).reshape(256,256)
l2=np.frombuffer(d,np.uint8,65536,2+65536).reshape(256,256)
al=np.frombuffer(d,np.uint8,65536,2+131072).reshape(256,256)
# --- height
h=open(W1+'/TerrainHeight.OZB','rb').read()
hb=np.frombuffer(h,np.uint8,65536,4+1080).reshape(256,256)
# --- attributes
a=bytearray(bmd.map_decrypt(open(W1+'/EncTerrain1.att','rb').read()))
bux=[0xFC,0xCF,0xAB]
for i in range(len(a)): a[i]^=bux[i%3]
print('att hdr',a[:4],len(a))
if len(a)==65536*2+4: att=np.frombuffer(bytes(a),np.uint16,65536,4).reshape(256,256)&0xFF
else: att=np.frombuffer(bytes(a),np.uint8,65536,4).reshape(256,256)
print('check lorencia att[123][135]=',att[123,135])
# --- light
lim=Image.open(io.BytesIO(open(W1+'/TerrainLight.OZJ','rb').read()[24:])).convert('RGB')
light=np.asarray(lim,np.float32)/255.0
print('light',lim.size)
# normals (MU space, z up)
H=hb.astype(np.float32)*1.5
def Hr(x,y): return H[y&255,x&255]
N=np.zeros((256,256,3))
ys,xs=np.mgrid[0:256,0:256]
def V(x,y): return np.stack([x*100.0,y*100.0,H[(y)&255,(x)&255]],-1)
v4=V(xs,ys); v1=V(xs+1,ys); v2=V(xs+1,ys+1); v3=V(xs,ys+1)
def fn(a,b,c):
    n=np.cross(b-a,c-a); return n/np.linalg.norm(n,axis=-1,keepdims=True)
N=fn(v1,v2,v3)+fn(v3,v4,v1)
sun=np.array([0.5,-0.5,0.5])
lum=np.clip((N*sun).sum(-1)+0.5,0,1)
final=np.clip(light*lum[...,None],0,1)
# all-opaque flag per tile
A=al.astype(np.int32)
flag=((A>=255)&(np.roll(A,-1,1)>=255)&(np.roll(np.roll(A,-1,1),-1,0)>=255)&(np.roll(A,-1,0)>=255)).astype(np.uint8)*255
print('layers used l1',np.unique(l1),'l2',np.unique(l2))
np.savez('/tmp/claude-0/-home-claude/1d3f39cc-f992-51e3-b270-8ed98722b989/scratchpad/conv/terrain.npz',l1=l1,l2=l2,al=al,hb=hb,att=att,final=final,flag=flag)
# save preview pngs
Image.fromarray((final*255).astype(np.uint8)).save('/tmp/claude-0/-home-claude/1d3f39cc-f992-51e3-b270-8ed98722b989/scratchpad/conv/light_prev.png')
Image.fromarray(hb).save('/tmp/claude-0/-home-claude/1d3f39cc-f992-51e3-b270-8ed98722b989/scratchpad/conv/h_prev.png')
Image.fromarray(((att&4)>0).astype(np.uint8)*255).save('/tmp/claude-0/-home-claude/1d3f39cc-f992-51e3-b270-8ed98722b989/scratchpad/conv/att_prev.png')
m1=Image.open(io.BytesIO(open(W1+'/map1.OZJ','rb').read()[24:])); print('map1',m1.size); m1.save('/tmp/claude-0/-home-claude/1d3f39cc-f992-51e3-b270-8ed98722b989/scratchpad/conv/map1.png')
