import bmd, struct, json, math, os, io, glob, sys
import numpy as np
from PIL import Image

SRC='/mnt/user-data/uploads/MuMain/Client/Data'
OUT='/mnt/user-data/outputs/MuGodot/assets/lorencia'
os.makedirs(OUT+'/models',exist_ok=True); os.makedirs(OUT+'/terrain',exist_ok=True)

# ---------- type -> model file ----------
TYPES={}
def reg(base,name,count):
    for i in range(count): TYPES[base+i]='%s%02d'%(name,i+1)
reg(0,'Tree',13); reg(20,'Grass',8); reg(30,'Stone',5); reg(40,'StoneStatue',3); TYPES[43]='SteelStatue01'
reg(44,'Tomb',3); reg(50,'FireLight',2); TYPES[52]='Bonfire01'; TYPES[55]='DoungeonGate01'
reg(56,'MerchantAnimal',2); TYPES[58]='TreasureDrum01'; TYPES[59]='TreasureChest01'; TYPES[60]='Ship01'
reg(65,'SteelWall',3); TYPES[68]='SteelDoor01'; reg(69,'StoneWall',6); reg(75,'StoneMuWall',4)
TYPES[80]='Bridge01'; reg(81,'Fence',4); TYPES[85]='BridgeStone01'; TYPES[90]='StreetLight01'; reg(91,'Cannon',3)
TYPES[95]='Curtain01'; reg(96,'Sign',2); reg(98,'Carriage',4); reg(102,'Straw',2); TYPES[105]='Waterspout01'
reg(106,'Well',4); TYPES[110]='Hanging01'; TYPES[111]='Stair01'; reg(115,'House',5); TYPES[120]='Tent01'
reg(121,'HouseWall',6); reg(127,'HouseEtc',3); reg(130,'Light',3); TYPES[133]='PoseBox01'; reg(140,'Furniture',7)
TYPES[150]='Candle01'; reg(151,'Beer',3)

# ---------- textures ----------
def find_src(dirn, texname):
    stem,ext=os.path.splitext(texname)
    want = '.ozj' if ext.lower() in ('.jpg','.jpeg') else '.ozt'
    for f in os.listdir(dirn):
        s,e=os.path.splitext(f)
        if s.lower()==stem.lower() and e.lower()==want: return os.path.join(dirn,f)
    return None

def decode_tex(path):
    d=open(path,'rb').read()
    if path.lower().endswith('.ozj'):
        return Image.open(io.BytesIO(d[24:])).convert('RGB'), False
    # OZT: 4 byte prefix + 18 byte TGA header, 32bpp BGRA rows bottom-up (MU always flips)
    w=d[4+12]|(d[4+13]<<8); h=d[4+14]|(d[4+15]<<8); bpp=d[4+16]
    if bpp==32 and d[4+2]==2:
        px=np.frombuffer(d,np.uint8,w*h*4,22).reshape(h,w,4)[::-1]
        rgba=px[:,:,[2,1,0,3]]
        return Image.fromarray(np.ascontiguousarray(rgba),'RGBA'), True
    im=Image.open(io.BytesIO(d[4:])); return im.convert('RGBA'), True

_texcache={}
def tex_png(texname):
    if texname in _texcache: return _texcache[texname]
    p=find_src(SRC+'/Object1',texname)
    if not p: print('MISSING TEX',texname); _texcache[texname]=None; return None
    im,alpha=decode_tex(p)
    if alpha:
        a=np.array(im)[:,:,3]
        if a.min()>=250: alpha=False; im=im.convert('RGB')
    b=io.BytesIO(); im.save(b,'PNG',optimize=True)
    _texcache[texname]=(b.getvalue(),alpha); return _texcache[texname]

# ---------- glTF writer ----------
C=np.array([[1,0,0],[0,0,1],[0,-1,0]],float)   # MU(x,y,z) -> Godot(x,z,-y)
S=0.01
def conv_mat(M):
    """4x4 MU-space transform -> Godot-space"""
    R=np.eye(4); R[:3,:3]=C@M[:3,:3]@C.T; R[:3,3]=C@M[:3,3]*S; return R

class GLB:
    def __init__(s): s.bin=bytearray(); s.g={'asset':{'version':'2.0','generator':'MuGodot BMD converter'},'buffers':[],'bufferViews':[],'accessors':[],'meshes':[],'nodes':[],'materials':[],'textures':[],'images':[],'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}],'scenes':[{'nodes':[]}],'scene':0}
    def view(s,data,target=None):
        while len(s.bin)%4: s.bin.append(0)
        off=len(s.bin); s.bin+=data
        v={'buffer':0,'byteOffset':off,'byteLength':len(data)}
        if target: v['target']=target
        s.g['bufferViews'].append(v); return len(s.g['bufferViews'])-1
    def acc(s,arr,ctype,typ,target=None,minmax=False):
        arr=np.ascontiguousarray(arr)
        bv=s.view(arr.tobytes(),target)
        a={'bufferView':bv,'componentType':ctype,'count':int(arr.shape[0]),'type':typ}
        if minmax: a['min']=[float(x) for x in arr.min(0)]; a['max']=[float(x) for x in arr.max(0)]
        s.g['accessors'].append(a); return len(s.g['accessors'])-1
    def material(s,name,texname,alpha):
        t=tex_png(texname)
        m={'name':name,'pbrMetallicRoughness':{'metallicFactor':0.0,'roughnessFactor':1.0},'doubleSided':True}
        if t:
            bv=s.view(t[0]); s.g['images'].append({'bufferView':bv,'mimeType':'image/png','name':os.path.splitext(texname)[0]})
            s.g['textures'].append({'source':len(s.g['images'])-1,'sampler':0})
            m['pbrMetallicRoughness']['baseColorTexture']={'index':len(s.g['textures'])-1}
            if t[1]: m['alphaMode']='MASK'; m['alphaCutoff']=0.25
        s.g['materials'].append(m); return len(s.g['materials'])-1
    def save(s,path):
        s.g['buffers']=[{'byteLength':len(s.bin)}]
        for k in ['textures','images']:
            if not s.g[k]: del s.g[k]
        js=json.dumps(s.g,separators=(',',':')).encode()
        while len(js)%4: js+=b' '
        while len(s.bin)%4: s.bin.append(0)
        out=struct.pack('<III',0x46546C67,2,12+8+len(js)+8+len(s.bin))+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(s.bin),0x004E4942)+bytes(s.bin)
        open(path,'wb').write(out)

def is_animated(m):
    for ai,nk in enumerate(m.actions):
        if nk<=1: continue
        for b in m.bones:
            if b.dummy or b.pos[ai] is None: continue
            if np.ptp(b.pos[ai],0).max()>1e-3 or np.ptp(b.rot[ai],0).max()>1e-4: return True
    return False

def build_geometry(m, mats, skinned):
    """returns list of (material index, positions, normals, uvs, joints, indices)"""
    prims=[]
    for mi,me in enumerate(m.meshes):
        verts={}; P=[];N=[];T=[];J=[];I=[]
        for poly,vi,ni,ti in me.tris:
            corners=[]
            for k in range(poly):
                key=(vi[k],ni[k],ti[k])
                if key not in verts:
                    v=me.v[vi[k]]; n=me.n[ni[k]]; t=me.t[ti[k]]
                    node=int(v['node']); Mb=mats[node] if 0<=node<len(mats) else np.eye(4)
                    p=Mb[:3,:3]@v['pos']+Mb[:3,3]
                    nn=Mb[:3,:3]@n['nrm']
                    P.append(C@p*S); ln=np.linalg.norm(nn); N.append(C@(nn/ln if ln>1e-6 else np.array([0,0,1.])))
                    T.append((t[0],t[1])); J.append(node if 0<=node<len(mats) else 0)
                    verts[key]=len(P)-1
                corners.append(verts[key])
            if poly==3: I+= [corners[0],corners[1],corners[2]]
            elif poly==4: I+= [corners[0],corners[1],corners[2],corners[0],corners[2],corners[3]]
        if not I: continue
        prims.append((mi,np.array(P,np.float32),np.array(N,np.float32),np.array(T,np.float32),np.array(J,np.uint16),np.array(I,np.uint32)))
    return prims

def export_model(name, path):
    m=bmd.load(path)
    anim=is_animated(m)
    mats0=bmd.bone_matrices(m,0,0) if m.actions and m.actions[0]>0 else [np.eye(4)]*len(m.bones)
    g=GLB(); G=g.g
    matidx={}
    for mi,me in enumerate(m.meshes):
        texname=me.texname
        tx=os.path.splitext(texname)[0]
        matidx[mi]=g.material('mu%d__%s'%(me.tex_index,tx), texname, None)
    prims=build_geometry(m,mats0,anim)
    gprims=[]
    for mi,P,N,T,J,I in prims:
        attrs={'POSITION':g.acc(P,5126,'VEC3',34962,True),'NORMAL':g.acc(N,5126,'VEC3',34962),'TEXCOORD_0':g.acc(T,5126,'VEC2',34962)}
        if anim:
            j4=np.zeros((len(J),4),np.uint16); j4[:,0]=J
            w4=np.zeros((len(J),4),np.float32); w4[:,0]=1
            attrs['JOINTS_0']=g.acc(j4,5123,'VEC4',34962); attrs['WEIGHTS_0']=g.acc(w4,5126,'VEC4',34962)
        gprims.append({'attributes':attrs,'indices':g.acc(I,5125,'SCALAR',34963),'material':matidx[mi]})
    G['meshes'].append({'name':name,'primitives':gprims})
    if not anim:
        G['nodes'].append({'name':name,'mesh':0}); G['scenes'][0]['nodes']=[0]
    else:
        nb=len(m.bones)
        # bone nodes 0..nb-1 ; mesh node nb ; root nb+1
        locals_=[]
        for i,b in enumerate(m.bones):
            node={'name':(b.name if not b.dummy and b.name else 'dummy%d'%i).replace(' ','_')+'_%d'%i}
            if not b.dummy and b.pos[0] is not None:
                q=bmd.angle_quat(b.rot[0][0]); qv=C@np.array(q[:3])
                node['rotation']=[float(qv[0]),float(qv[1]),float(qv[2]),float(q[3])]
                t=C@b.pos[0][0]*S; node['translation']=[float(x) for x in t]
            G['nodes'].append(node)
        roots=[]
        for i,b in enumerate(m.bones):
            if not b.dummy and b.parent>=0:
                G['nodes'][b.parent].setdefault('children',[]).append(i)
            else: roots.append(i)
        ibm=np.array([np.linalg.inv(conv_mat(mats0[i])).T for i in range(nb)],np.float32).reshape(nb,16)
        G['skins']=[{'joints':list(range(nb)),'inverseBindMatrices':g.acc(ibm,5126,'MAT4')}]
        G['nodes'].append({'name':name+'_mesh','mesh':0,'skin':0})
        G['nodes'].append({'name':name,'children':roots+[nb]})
        G['scenes'][0]['nodes']=[nb+1]
        G['animations']=[]
        for ai,nk in enumerate(m.actions):
            if nk<=1: continue
            times=np.arange(nk+1,dtype=np.float32)/4.0   # 0.16 keys/tick * 25 ticks/s = 4 keys/s, loop back to key 0
            tacc=g.acc(times.reshape(-1,1),5126,'SCALAR',None,True)
            chans=[];samps=[]
            for i,b in enumerate(m.bones):
                if b.dummy or b.pos[ai] is None: continue
                keys=list(range(nk))+[0]
                tr=np.array([C@b.pos[ai][k]*S for k in keys],np.float32)
                rq=[]
                prev=None
                for k in keys:
                    q=bmd.angle_quat(b.rot[ai][k]); qv=C@np.array(q[:3]); qq=np.array([qv[0],qv[1],qv[2],q[3]])
                    if prev is not None and np.dot(prev,qq)<0: qq=-qq
                    rq.append(qq); prev=qq
                rq=np.array(rq,np.float32)
                samps.append({'input':tacc,'output':g.acc(tr,5126,'VEC3'),'interpolation':'LINEAR'}); chans.append({'sampler':len(samps)-1,'target':{'node':i,'path':'translation'}})
                samps.append({'input':tacc,'output':g.acc(rq,5126,'VEC4'),'interpolation':'LINEAR'}); chans.append({'sampler':len(samps)-1,'target':{'node':i,'path':'rotation'}})
            G['animations'].append({'name':'idle' if ai==0 else 'action%d'%ai,'channels':chans,'samplers':samps})
        if not G['animations']: del G['animations']
    for k in ['materials']:
        if not G[k]: del G[k]
    g.save(path_out(name))
    return anim, m

def path_out(name): return OUT+'/models/%s.glb'%name

if __name__=='__main__':
    info={}
    names=sorted(set(TYPES.values())|{'Bird01','Fish01'})
    for n in names:
        p=SRC+'/Object1/%s.bmd'%n
        anim,m=export_model(n,p)
        info[n]={'animated':anim,'meshes':[{'tex_index':me.tex_index,'tex':me.texname} for me in m.meshes],'actions':m.actions}
        print(n,'anim' if anim else 'static', os.path.getsize(path_out(n)))
    json.dump(info,open('/tmp/claude-0/-home-claude/1d3f39cc-f992-51e3-b270-8ed98722b989/scratchpad/conv/model_info.json','w'),indent=1)
