"""Raccords d'une couche de décor (voir la remise à plat du rendu).

1. Bords coupés par le cadre : là où l'objet touche le bord gauche, droit ou bas de l'image
   (un tas de gravats coupé net), l'alpha s'efface en pente douce, en forme de butte.
2. Colorimétrie : chaque élément est ramené vers la moyenne de couleur de son plan (LAB,
   moyenne et écart, part « force »), pour qu'aucun ne détonne (plus rouge, plus clair...).

Usage : python3 raccord.py force sortie_dir image1.png image2.png ...  (les images d'un même plan)
"""
import sys, os, numpy as np, cv2

def fondu_bords(im):
    a = im[..., 3].astype(np.float32) / 255
    h, w = a.shape
    k = np.ones_like(a)
    xs = np.arange(w, dtype=np.float32)
    ys = np.arange(h, dtype=np.float32)
    for side in ("g", "d"):
        col = a[:, 0] if side == "g" else a[:, -1]
        if (col > 0.5).sum() < h * 0.03:
            continue
        # hauteur coupée par le bord : la pente s'étend d'autant plus loin
        top = np.argmax(col > 0.5)
        span = max(0.18 * w, (h - top) * 1.2)
        t = (xs if side == "g" else (w - 1 - xs)) / span
        # butte : plus on est haut dans la zone coupée, plus le fondu commence tôt
        rel = np.clip((ys[:, None] - top) / max(h - top, 1), 0, 1)
        f = np.clip((t[None, :] - (1 - rel) * 0.0) * (0.6 + 0.8 * (1 - rel)), 0, 1)
        f = f * f * (3 - 2 * f)
        k = np.minimum(k, np.where(ys[:, None] >= top - 2, f, 1.0))
    row = a[-1]
    if (row > 0.5).sum() > w * 0.1:
        t = (h - 1 - ys) / (0.12 * h)
        f = np.clip(t, 0, 1); f = f * f * (3 - 2 * f)
        k = np.minimum(k, f[:, None])
    im[..., 3] = (a * k * 255).astype(np.uint8)
    return im

def stats(im):
    a = im[..., 3] > 200
    lab = cv2.cvtColor(im[..., :3], cv2.COLOR_BGR2LAB).astype(np.float32)
    v = lab[a]
    return v.mean(0), v.std(0) + 1e-3

def harmonise(im, ref_m, ref_s, force):
    lab = cv2.cvtColor(im[..., :3], cv2.COLOR_BGR2LAB).astype(np.float32)
    m, s = stats(im)
    out = (lab - m) / s * ref_s + ref_m
    lab = lab * (1 - force) + out * force
    im[..., :3] = cv2.cvtColor(np.clip(lab, 0, 255).astype(np.uint8), cv2.COLOR_LAB2BGR)
    return im

if __name__ == "__main__":
    force = float(sys.argv[1]); outd = sys.argv[2]; files = sys.argv[3:]
    ims = [cv2.imread(f, cv2.IMREAD_UNCHANGED) for f in files]
    st = [stats(i) for i in ims]
    ref_m = np.median([s[0] for s in st], 0); ref_s = np.median([s[1] for s in st], 0)
    for f, im in zip(files, ims):
        im = harmonise(im, ref_m, ref_s, force)
        im = fondu_bords(im)
        cv2.imwrite(os.path.join(outd, os.path.basename(f)), im)
        print(os.path.basename(f), "écart de couleur avant :", np.round(stats(cv2.imread(f, cv2.IMREAD_UNCHANGED))[0] - ref_m, 1))
