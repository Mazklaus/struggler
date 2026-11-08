# Détourage fin : BiRefNet (forme) + distance au fond uni (trous) -> trimap -> pymatting (alpha
# fin + couleurs du premier plan sans liseré du fond).
import sys,time,numpy as np,cv2
from PIL import Image
from rembg import remove,new_session
from pymatting import estimate_alpha_lkm, estimate_foreground_ml
sess=new_session('birefnet-general')
for src,dst in zip(sys.argv[1::2],sys.argv[2::2]):
    t=time.time()
    pil=Image.open(src).convert('RGB'); im=np.asarray(pil).astype(np.float64)/255
    h,w=im.shape[:2]
    a0=np.asarray(remove(pil,session=sess,only_mask=True)).astype(np.float64)/255
    lab=cv2.cvtColor(im.astype(np.float32),cv2.COLOR_RGB2LAB)
    border=np.concatenate([lab[:8].reshape(-1,3),lab[:,:8].reshape(-1,3),lab[:,-8:].reshape(-1,3)])
    bg=np.median(border,0); d=np.linalg.norm(lab-bg,axis=2)
    # objet = taches de couleur (loin du fond) reliées à la forme BiRefNet ou au bord bas (socle)
    m=cv2.morphologyEx((d>16).astype(np.uint8),cv2.MORPH_OPEN,np.ones((3,3),np.uint8))
    n,lab_=cv2.connectedComponents(m)
    core=a0>0.5; keep=np.zeros((h,w),bool)
    ids=set(np.unique(lab_[core]))|set(np.unique(lab_[-3:,:]))
    ids.discard(0)
    keep=np.isin(lab_,list(ids))
    fg=cv2.erode((keep&(d>24)).astype(np.uint8),np.ones((3,3),np.uint8))>0
    bgm=(d<6)|~(cv2.dilate(keep.astype(np.uint8),np.ones((7,7),np.uint8))>0)
    bgm=cv2.erode(bgm.astype(np.uint8),np.ones((3,3),np.uint8))>0
    tri=np.full((h,w),0.5); tri[fg]=1; tri[bgm&~fg]=0
    alpha=estimate_alpha_lkm(im,tri,laplacian_kwargs={"radius":3})
    alpha=np.clip(alpha,0,1); alpha[alpha<0.02]=0; alpha[alpha>0.98]=1
    F=estimate_foreground_ml(im,alpha)
    ys,xs=np.nonzero(alpha>0.02)
    out=np.dstack([F,alpha])[ys.min():ys.max()+1,xs.min():xs.max()+1]
    Image.fromarray((np.clip(out,0,1)*255).astype(np.uint8)).save(dst)
    print(dst,out.shape,round(time.time()-t,1),'s',flush=True)
