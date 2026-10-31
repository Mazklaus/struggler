# Struggler — prototype gris

Prototype sans graphismes du fan-game *Struggler* (Godot 4). Le seul but est de vérifier
que le jeu est agréable à jouer : déplacements nerveux façon Silksong, combat en
**Cadence** au marteau, **Rage** et **Panser**, un ennemi, sur des blocs gris.

## Lancer le jeu

1. Télécharger **Godot 4.6**, version standard (pas « .NET ») :
   https://godotengine.org/download
2. Récupérer ce dépôt (bouton *Code > Download ZIP* sur GitHub, ou `git clone`).
3. Ouvrir Godot, cliquer sur **Importer**, choisir le fichier `project.godot` du dossier.
4. Appuyer sur **F5** (ou le bouton ▶ en haut à droite).

Une manette Xbox ou PlayStation fonctionne aussi.

## Commandes

| Action | Clavier | Manette |
|---|---|---|
| Se déplacer | flèches ou ZQSD | stick gauche |
| Sauter (maintenir = plus haut) | Espace | A |
| Frapper (+ haut, + bas en l'air) | J | X |
| Attaque lourde (maintenir, relâcher) | K | Y |
| Ruée (esquive, invincible) | Maj ou L | RB |
| Glissade | C | RT |
| Contre | I | LB |
| Panser | F | B |
| Trempe | E | LT |
| Recommencer | R | Back |
| Afficher / cacher l'aide | H | Start |

## Ce qu'il faut essayer

- **La Cadence.** Frapper le mannequin au son de l'enclume : un tintement sonne au moment
  idéal pour la frappe suivante (toutes les 0,5 s, à 0,13 s près), et l'anneau en bas de l'écran se
  referme sur sa cible. En rythme, l'arme chauffe ; trop tôt ou trop tard, le rythme casse
  et la Chaleur baisse. Marteler le bouton ne marche pas.
- **La Chaleur.** Trois paliers : *rougeoie* (+1 dégât, brûlure), *brise-garde* (les coups
  légers brisent le bouclier du soldat), *à blanc* : la frappe suivante est une
  **Frappe à blanc**, une explosion d'étincelles qui sonne la cloche. Après elle, la Chaleur
  retombe au palier brise-garde (réglage `heat_after_blanc`). La Chaleur retombe si
  on arrête de frapper.
- **La Trempe.** Dans l'eau, dans une flaque de sang ou à côté d'un soldat à terre : `E`
  refroidit l'arme d'un coup et donne 3 s de vitesse. Garder la Chaleur ou la dépenser ?
- **Le soldat.** Il avance bouclier levé (frapper le bouclier en rythme chauffe quand même
  l'arme, et finit par le fendre), prévient avant son coup de lance (contour rouge, « ! »),
  puis reste ouvert. Les coups légers n'interrompent pas son attaque : il faut esquiver ou
  contrer. Un contre réussi ou une garde brisée le met **à terre** (dégâts ×1,5, trempe
  possible). Il réapparaît 6 s après sa mort.
- **Rage et Panser.** La Rage monte en frappant et en étant blessé. `F` dépense 33 de Rage
  pour rendre 3 PV après une seconde immobile ; un coup pendant ce temps gâche le bandage.
  À la mort, la Rage est perdue.
- **Le parcours.** Glissade sous le passage bas, pics (on peut rebondir dessus avec une
  frappe vers le bas), mur fissuré à briser avec une attaque lourde chargée.

## Régler les sensations

Tous les réglages sont en haut des scripts, avec des commentaires :

- `scripts/player.gd` : vitesse, saut, ruée, tempo de la Cadence (`beat`, `tolerance`),
  gains et pertes de Chaleur, Rage, Panser, fenêtre de contre.
- `scripts/soldier.gd` : vie, vitesse, durée du signal d'attaque, bouclier.
- `scripts/main.gd` : le niveau, dessiné en caractères (`#` bloc, `X` mur fragile,
  `^` pics, `~` eau, `E` soldat, `D` mannequin, `P` départ).

## Test automatique

```
godot --headless res://tests/smoke_test.tscn
```

Pilote Wendel avec de fausses touches et vérifie course, saut, Cadence, Frappe à blanc,
trempe, glissade, pics, mur fragile, attaque du soldat, contre, Panser et mort du soldat.

Fan-game privé, non commercial, d'après *Berserk* de Kentaro Miura.
