# La vraie DA « Encre et couleur »

L'habillage se pose **par-dessus** le jeu gris, sans changer le gameplay : collisions, ennemis et
objets restent ceux des salles grises. **F2** bascule entre la DA et le gris.

## Où vont les fichiers

- `art/zones/<zone>/zone.json` : salles habillées, leurs fonds, palettes et voile. Une salle absente reste grise.
- `art/zones/<zone>/fonds/` : fonds peints (JPEG), en parallaxe derrière la salle.
- `art/zones/<zone>/matieres/` : textures qui se répètent (512 px = 8 tuiles), une par matière des blocs :
  roche, bois, maconnerie, chair, eboulis, fer. Seules leurs **valeurs** comptent : la couleur vient de la
  matière et de la palette de la salle.
- `art/zones/<zone>/decors/` : objets détourés (à venir).
- `art/personnages/wendel/` : planches d'animation à 12 i/s + leur description JSON (à venir).
- `art/shaders/` : encre des blocs (contour, hachures, liseré de lumière) et grain de papier.
- Les originaux Midjourney ne sont pas dans le dépôt : ils sont gardés dans le dossier du projet
  (`struggler-da/sources/`).

## Conventions

- Écran de référence 1280×720, tuile de 32 px ; l'art est produit au double (64 px par tuile).
- Noms en minuscules, sans accent.
- Tout passe par `tools/art/art.py` (relançable) : `fond`, `matiere`, `decor`, `wendel`. Voir `--help`.
- Détourage par IA : `pip install "rembg[cpu]"` ; BiRefNet (~1 Go) pour les décors, ISNet pour les images de Wendel. Les modèles se téléchargent au premier usage.

## Palette d'une salle (zone.json)

`encre` (contours et hachures), `ombre` (cœur des blocs, teinté, jamais noir), `lumiere` (liserés,
halos des brasiers), `brume` + `voile` (brume entre le fond et les blocs ; plus le voile est fort,
plus le fond recule). Le vert-bleu reste réservé aux esprits.

## Netteté (2026-11-02)

- Les planches de Wendel sont en haute définition (personnage de 336 px dans la planche, couleurs complètes) : le jeu les réduit à 62 px à l'échelle 1, et elles restent nettes en 1440p et en 4K. Les planches passent à la ligne au-delà de 8192 px (« colonnes » dans le .json).
- Tout l'art est importé avec mipmaps (`mipmaps/generate=true` dans les .import) et affiché en filtrage linéaire avec mipmaps : une image réduite à l'écran ne crénèle pas. Pour une nouvelle image, cocher « Mipmaps > Generate » à l'import (ou copier un .import existant).
