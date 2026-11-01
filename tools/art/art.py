#!/usr/bin/env python3
"""Chaîne de traitement de la vraie DA : des images Midjourney (et des vidéos) aux fichiers du jeu.

Toutes les commandes lisent un original (jamais modifié) et écrivent dans art/.
Les images Midjourney arrivent souvent en grille de 4 : --quart 1..4 choisit la vignette
(1 haut gauche, 2 haut droite, 3 bas gauche, 4 bas droite), 0 = l'image entière.

  fond     : fond peint pour la parallaxe (recadré, étalonné, réduit).
  matiere  : texture de matière qui se répète sans couture (512 px = 8 tuiles de jeu au double).
  decor    : objet sur fond uni -> détouré, rogné.
  wendel   : vidéo d'une animation -> images à 12 i/s, détourées, recalées sur les pieds,
             même échelle, palette et encre communes, planche + description JSON.

Exemples :
  python3 tools/art/art.py fond SRC.png art/zones/hautfer/fonds/carreau.jpg --quart 4 --crop 0,0,1,0.8
  python3 tools/art/art.py matiere SRC.png art/zones/hautfer/matieres/roche.png --quart 3 --crop 0,0.2,0.3,0.6
  python3 tools/art/art.py decor SRC.png art/zones/hautfer/decors/wagonnet.png --quart 1
  python3 tools/art/art.py wendel course.mp4 art/personnages/wendel/course --boucle
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageFilter

# Mise à l'échelle : le jeu tourne en 1280x720 avec des tuiles de 32 px, l'art est produit au double.
SCALE = 2
TILE = 32 * SCALE


# --- Outils communs ---------------------------------------------------------

def load(path, quart=0):
    im = Image.open(path).convert("RGBA")
    if quart:
        w, h = im.size
        i = quart - 1
        im = im.crop(((i % 2) * w // 2, (i // 2) * h // 2, (i % 2 + 1) * w // 2, (i // 2 + 1) * h // 2))
    return im


def crop_frac(im, spec):
    """--crop x0,y0,x1,y1 en fractions de l'image (0..1)."""
    if not spec:
        return im
    x0, y0, x1, y1 = (float(v) for v in spec.split(","))
    w, h = im.size
    return im.crop((int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h)))


def grade(im, sat=1.0, gain=1.0, lift=0.0):
    """Étalonnage léger : saturation, gain et relevé des noirs (les ombres ne sont jamais noires)."""
    a = np.asarray(im).astype(np.float32) / 255.0
    rgb, alpha = a[..., :3], a[..., 3:]
    lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    rgb = lum[..., None] + (rgb - lum[..., None]) * sat
    rgb = lift + rgb * gain * (1.0 - lift)
    out = np.concatenate([np.clip(rgb, 0, 1), alpha], axis=-1)
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


def save(im, out):
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    if out.lower().endswith((".jpg", ".jpeg")):
        im.convert("RGB").save(out, quality=88, optimize=True)   # fonds : opaques, bien plus légers
    else:
        im.save(out, optimize=True)
    print(f"{out}  {im.size[0]}x{im.size[1]}")


def key_background(im, tol=38.0, feather=1.5):
    """Détoure un sujet posé sur un fond uni : on remplit depuis les bords tout ce qui
    ressemble à la couleur du fond, le reste est le sujet."""
    a = np.asarray(im.convert("RGB")).astype(np.float32)
    h, w, _ = a.shape
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(border, axis=0)
    near = np.linalg.norm(a - bg, axis=-1) < tol
    # Remplissage depuis les bords (seul le fond relié au cadre est retiré, pas les gris du sujet).
    mask = np.zeros((h, w), bool)
    stack = [(y, x) for x in range(w) for y in (0, h - 1)] + [(y, x) for y in range(h) for x in (0, w - 1)]
    while stack:
        y, x = stack.pop()
        if mask[y, x] or not near[y, x]:
            continue
        mask[y, x] = True
        if y > 0: stack.append((y - 1, x))
        if y < h - 1: stack.append((y + 1, x))
        if x > 0: stack.append((y, x - 1))
        if x < w - 1: stack.append((y, x + 1))
    alpha = Image.fromarray(((~mask) * 255).astype(np.uint8), "L")
    alpha = alpha.filter(ImageFilter.MinFilter(3))   # ronge le liseré clair laissé par le fond
    if feather:
        alpha = alpha.filter(ImageFilter.GaussianBlur(feather))
    out = im.convert("RGBA")
    out.putalpha(alpha)
    return out


_SESSION = None
_MODEL = "birefnet-general"


def key_ai(im):
    """Détourage par IA (rembg + BiRefNet) : bords nets, ombres portées et sol retirés.
    Le modèle (~1 Go) se télécharge au premier usage dans ~/.u2net. Sans rembg, on retombe
    sur le détourage par couleur de fond."""
    global _SESSION
    try:
        from rembg import new_session, remove
    except ImportError:
        print("rembg absent (pip install \"rembg[cpu]\") : détourage par couleur de fond")
        return key_background(im)
    if _SESSION is None:
        _SESSION = new_session(_MODEL)
    return remove(im.convert("RGBA"), session=_SESSION)


def cut(im, a):
    global _MODEL
    _MODEL = getattr(a, "modele", _MODEL)
    return key_background(im, a.tol) if a.detourage == "couleur" else key_ai(im)


def trim(im, pad=4):
    box = im.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
    if not box:
        return im
    x0, y0, x1, y1 = box
    return im.crop((max(0, x0 - pad), max(0, y0 - pad), min(im.width, x1 + pad), min(im.height, y1 + pad)))


# --- Fond -------------------------------------------------------------------

def cmd_fond(a):
    im = crop_frac(load(a.src, a.quart), a.crop)
    h = a.hauteur
    im = im.resize((round(im.width * h / im.height), h), Image.LANCZOS)
    im = grade(im, sat=a.sat, gain=a.gain, lift=a.lift)
    save(im.convert("RGB"), a.out)


# --- Matière ----------------------------------------------------------------

def make_seamless(im, blend=0.25):
    """Rend une texture raccordable : on la décale d'une demi-taille et on fond les jointures
    avec la version d'origine (masque en croix adouci)."""
    a = np.asarray(im).astype(np.float32)
    h, w, _ = a.shape
    shifted = np.roll(np.roll(a, h // 2, axis=0), w // 2, axis=1)
    # Poids de l'original : 1 au centre, 0 vers les bords (là où l'original ne se raccorde pas).
    yy = np.minimum(np.arange(h), h - 1 - np.arange(h)) / (h * blend)
    xx = np.minimum(np.arange(w), w - 1 - np.arange(w)) / (w * blend)
    wgt = np.clip(np.minimum(yy[:, None], xx[None, :]), 0, 1)[..., None]
    # Au centre du décalé se trouvent les jointures : l'original y est plein, donc on garde l'original
    # au centre et le décalé (qui, lui, raccorde aux bords) sur les bords.
    out = a * wgt + shifted * (1 - wgt)
    return Image.fromarray(out.clip(0, 255).astype(np.uint8), "RGBA")


def cmd_matiere(a):
    im = crop_frac(load(a.src, a.quart), a.crop)
    side = min(im.size)
    im = im.crop((0, 0, side, side)).resize((a.taille, a.taille), Image.LANCZOS)
    if not a.deja_raccord:
        im = make_seamless(im)
    im = grade(im, sat=a.sat, gain=a.gain, lift=a.lift)
    save(im.convert("RGB"), a.out)


# --- Décor ------------------------------------------------------------------

def cmd_decor(a):
    im = crop_frac(load(a.src, a.quart), a.crop)
    im = trim(cut(im, a))
    if a.hauteur:
        im = im.resize((round(im.width * a.hauteur / im.height), a.hauteur), Image.LANCZOS)
    im = grade(im, sat=a.sat, gain=a.gain, lift=a.lift)
    save(im, a.out)


# --- Wendel : vidéo -> images -----------------------------------------------

def extract_frames(video, fps, tmp):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-i", video, "-vf", f"fps={fps}",
                    os.path.join(tmp, "f%04d.png")], check=True)
    return sorted(os.path.join(tmp, f) for f in os.listdir(tmp) if f.endswith(".png"))


def feet_anchor(alpha):
    """Point d'appui : bas du personnage, centré sur la moitié basse de la silhouette (les hanches),
    pour que le corps ne glisse pas d'une image à l'autre même quand le marteau dépasse."""
    ys, xs = np.nonzero(alpha > 64)
    if len(ys) == 0:
        return None
    bottom = ys.max()
    top = ys.min()
    hips = (ys > top + (bottom - top) * 0.45) & (ys < top + (bottom - top) * 0.7)
    cx = np.median(xs[hips]) if hips.any() else np.median(xs)
    return float(cx), float(bottom), float(bottom - top)


def quantize_palette(frames, colors):
    """Palette commune à toutes les images : couleurs stables, le trait ne scintille plus."""
    sheet = Image.new("RGB", (sum(f.width for f in frames), max(f.height for f in frames)))
    x = 0
    for f in frames:
        sheet.paste(f.convert("RGB"), (x, 0), f)
        x += f.width
    pal = sheet.quantize(colors, method=Image.Quantize.MEDIANCUT)
    out = []
    for f in frames:
        q = f.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGBA")
        q.putalpha(f.getchannel("A"))
        out.append(q)
    return out


def cmd_wendel(a):
    with tempfile.TemporaryDirectory() as tmp:
        paths = extract_frames(a.src, a.fps, tmp)
        if a.debut or a.fin:
            paths = paths[a.debut: (a.fin or len(paths))]
        raw = [Image.open(p).convert("RGBA") for p in paths]
        for r in raw:
            r.load()
    # Choix de la boucle sur un détourage rapide, puis détourage soigné des seules images gardées.
    quick = [key_background(r, a.tol) for r in raw]
    keep = list(range(len(raw)))
    if a.boucle:
        keep = trim_loop_idx(quick)
    cutf = [cut(raw[i], a) for i in keep]
    anchors = [feet_anchor(np.asarray(c.getchannel("A"))) for c in cutf]
    good = [(c, an) for c, an in zip(cutf, anchors) if an]
    if not good:
        sys.exit("aucun personnage trouvé : fond trop chargé ?")
    # Même échelle : la taille médiane du personnage devient a.hauteur (pieds à la tête, repos).
    med = float(np.median([an[2] for _, an in good]))
    k = a.hauteur / med
    W = H = int(a.hauteur * 1.9)          # cadre commun, assez large pour le marteau
    foot = (W // 2, int(H * 0.92))        # point d'appui dans le cadre
    frames = []
    for c, (cx, by, _) in good:
        c = c.resize((round(c.width * k), round(c.height * k)), Image.LANCZOS)
        f = Image.new("RGBA", (W, H))
        f.alpha_composite(c, (round(foot[0] - cx * k), round(foot[1] - by * k)))
        frames.append(f)
    if a.couleurs:
        frames = quantize_palette(frames, a.couleurs)
    os.makedirs(a.out, exist_ok=True)
    sheet = Image.new("RGBA", (W * len(frames), H))
    for i, f in enumerate(frames):
        sheet.alpha_composite(f, (i * W, 0))
    sheet_path = a.out.rstrip("/") + ".png"
    save(sheet, sheet_path)
    meta = {"images": len(frames), "largeur": W, "hauteur": H, "fps": a.fps,
            "appui": list(foot), "boucle": bool(a.boucle), "echelle_jeu": 1.0 / SCALE}
    with open(a.out.rstrip("/") + ".json", "w") as fh:
        json.dump(meta, fh, indent=1)
    os.rmdir(a.out) if not os.listdir(a.out) else None
    print(json.dumps(meta))


def trim_loop_idx(frames, pmin=5, pmax=24):
    """Garde un cycle propre : cherche la période (en images) qui fait le mieux revenir le personnage
    sur lui-même, en couleurs (pour distinguer la jambe avant de la jambe arrière), puis garde le
    cycle qui se referme le mieux."""
    if len(frames) < pmin * 2:
        return list(range(len(frames)))
    small = [np.asarray(f.resize((64, 64))).astype(np.float32) for f in frames]
    n = len(small)
    best_p, best_d = None, 1e9
    for p in range(pmin, min(pmax, n // 2) + 1):
        d = np.mean([np.abs(small[i] - small[i + p]).mean() for i in range(n - p)])
        if d < best_d:
            best_p, best_d = p, d
    best_s, best_e = 0, 1e9
    for s0 in range(0, n - best_p):
        e = np.abs(small[s0] - small[s0 + best_p]).mean()
        if e < best_e:
            best_s, best_e = s0, e
    print(f"boucle : {best_p} images à partir de l'image {best_s} (écart {best_e:.1f})")
    return list(range(best_s, best_s + best_p))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    def common(sp):
        sp.add_argument("src")
        sp.add_argument("out")
        sp.add_argument("--quart", type=int, default=0)
        sp.add_argument("--crop", default="")
        sp.add_argument("--sat", type=float, default=1.0)
        sp.add_argument("--gain", type=float, default=1.0)
        sp.add_argument("--lift", type=float, default=0.0)

    sp = sub.add_parser("fond"); common(sp)
    sp.add_argument("--hauteur", type=int, default=1440)
    sp.set_defaults(fn=cmd_fond)
    sp = sub.add_parser("matiere"); common(sp)
    sp.add_argument("--taille", type=int, default=512)
    sp.add_argument("--deja-raccord", action="store_true", help="image déjà faite avec --tile")
    sp.set_defaults(fn=cmd_matiere)
    sp = sub.add_parser("decor"); common(sp)
    sp.add_argument("--hauteur", type=int, default=0)
    sp.add_argument("--tol", type=float, default=38.0)
    sp.add_argument("--detourage", choices=["ia", "couleur"], default="ia")
    sp.set_defaults(fn=cmd_decor)
    sp = sub.add_parser("wendel")
    sp.add_argument("src"); sp.add_argument("out")
    sp.add_argument("--fps", type=int, default=12)
    sp.add_argument("--hauteur", type=int, default=112, help="taille du personnage en px (56 px en jeu, au double)")
    sp.add_argument("--tol", type=float, default=38.0)
    sp.add_argument("--debut", type=int, default=0)
    sp.add_argument("--fin", type=int, default=0)
    sp.add_argument("--boucle", action="store_true")
    sp.add_argument("--detourage", choices=["ia", "couleur"], default="ia")
    sp.add_argument("--couleurs", type=int, default=48)
    sp.add_argument("--modele", default="isnet-general-use", help="modèle rembg (plus léger que BiRefNet pour les vidéos)")
    sp.set_defaults(fn=cmd_wendel)
    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
