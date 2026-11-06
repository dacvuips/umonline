import struct, math, numpy as np

KEY=bytes([0xD1,0x73,0x52,0xF6,0xD2,0x9A,0xCB,0x27,0x3E,0xAF,0x59,0x31,0x37,0xB3,0xE7,0xA2])
def map_decrypt(src):
    out=bytearray(len(src)); k=0x5E
    for i,b in enumerate(src):
        out[i]=((b ^ KEY[i%16]) - k) & 0xFF
        k=(b+0x3D)&0xFF
    return bytes(out)

class BMD: pass

def angle_quat(a):
    sy,cy=math.sin(a[2]*.5),math.cos(a[2]*.5)
    sp,cp=math.sin(a[1]*.5),math.cos(a[1]*.5)
    sr,cr=math.sin(a[0]*.5),math.cos(a[0]*.5)
    return (sr*cp*cy-cr*sp*sy, cr*sp*cy+sr*cp*sy, cr*cp*sy-sr*sp*cy, cr*cp*cy+sr*sp*sy)

def quat_mat(q):
    x,y,z,w=q
    return np.array([[1-2*y*y-2*z*z, 2*x*y-2*w*z, 2*x*z+2*w*y],
                     [2*x*y+2*w*z, 1-2*x*x-2*z*z, 2*y*z-2*w*x],
                     [2*x*z-2*w*y, 2*y*z+2*w*x, 1-2*x*x-2*y*y]])

def load(path):
    d=open(path,'rb').read()
    assert d[:3]==b'BMD', path
    ver=d[3]
    if ver==0x0A: data=d; p=4
    elif ver==0x0C:
        n=struct.unpack_from('<i',d,4)[0]; data=map_decrypt(d[8:8+n]); p=0
    else: raise Exception('ver %x'%ver)
    m=BMD(); m.version=ver
    m.name=data[p:p+32].split(b'\0')[0].decode('latin1'); p+=32
    nm,nb,na=struct.unpack_from('<hhh',data,p); p+=6
    m.meshes=[]
    for i in range(nm):
        nv,nn,nt,ntri,tex=struct.unpack_from('<hhhhh',data,p); p+=10
        me=type('M',(),{})()
        me.tex_index=tex
        v=np.frombuffer(data,dtype=np.dtype([('node','<i2'),('pad','<i2'),('pos','<f4',3)]),count=nv,offset=p); p+=nv*16
        n=np.frombuffer(data,dtype=np.dtype([('node','<i2'),('pad','<i2'),('nrm','<f4',3),('bind','<i2'),('pad2','<i2')]),count=nn,offset=p); p+=nn*20
        t=np.frombuffer(data,dtype='<f4',count=nt*2,offset=p).reshape(-1,2); p+=nt*8
        tris=[]
        for j in range(ntri):
            poly=data[p]
            vi=struct.unpack_from('<4h',data,p+2); ni=struct.unpack_from('<4h',data,p+10); ti=struct.unpack_from('<4h',data,p+18)
            tris.append((poly,vi,ni,ti)); p+=64
        me.texname=data[p:p+32].split(b'\0')[0].decode('latin1').strip(); p+=32
        me.v=v; me.n=n; me.t=t; me.tris=tris
        m.meshes.append(me)
    m.actions=[]
    for i in range(na):
        nk=struct.unpack_from('<h',data,p)[0]; p+=2
        lock=data[p]; p+=1
        if lock and nk>0: p+=12*nk
        m.actions.append(nk)
    m.bones=[]
    for i in range(nb):
        dummy=data[p]; p+=1
        b=type('B',(),{})(); b.dummy=dummy
        if not dummy:
            b.name=data[p:p+32].split(b'\0')[0].decode('latin1'); p+=32
            b.parent=struct.unpack_from('<h',data,p)[0]; p+=2
            b.pos=[];b.rot=[]
            for nk in m.actions:
                if nk>0:
                    b.pos.append(np.frombuffer(data,'<f4',nk*3,p).reshape(-1,3)); p+=12*nk
                    b.rot.append(np.frombuffer(data,'<f4',nk*3,p).reshape(-1,3)); p+=12*nk
                else: b.pos.append(None); b.rot.append(None)
        m.bones.append(b)
    m.consumed=p; m.size=len(data)
    return m

def bone_matrices(m, action=0, key=0):
    """global 3x4 matrices for each bone (MU space)"""
    out=[]
    for i,b in enumerate(m.bones):
        M=np.eye(4)
        if not b.dummy and b.pos[action] is not None:
            q=angle_quat(b.rot[action][key]); M[:3,:3]=quat_mat(q); M[:3,3]=b.pos[action][key]
            if b.parent>=0: M=out[b.parent]@M
        out.append(M)
    return out
