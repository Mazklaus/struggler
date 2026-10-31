# Struggler — prototype gris

Prototype sans graphismes du fan-game *Struggler* (Godot 4.6). Le seul but est de vérifier
que le jeu est agréable à jouer : déplacements nerveux façon Silksong, deux armes forgées
(le **Marteau** et sa Cadence, les **Pics** et leur Entaille), **Rage** et **Panser**, un
ennemi, sur des blocs gris.

## Lancer le jeu

1. Télécharger **Godot 4.6**, version standard (pas « .NET ») :
   https://godotengine.org/download
2. Récupérer ce dépôt (bouton *Code > Download ZIP* sur GitHub, ou `git clone`).
3. Ouvrir Godot, cliquer sur **Importer**, choisir le fichier `project.godot` du dossier.
4. Appuyer sur **F5** (ou le bouton ▶ en haut à droite).

Une manette Xbox ou PlayStation fonctionne aussi.

## Commandes

| Action | Clavier | Manette Xbox |
|---|---|---|
| Se déplacer | flèches ou ZQSD | stick gauche |
| Sauter (maintenir = plus haut) | Espace | A |
| Frapper (+ haut, + bas en l'air) | J | X |
| Attaque lourde (Marteau : maintenir puis relâcher ; Pics : bond) | K | Y |
| Ruée (esquive, invincible) | Maj ou L | RB |
| Glissade | C | RT |
| Contre | I | LB |
| Panser | F | B |
| Trempe | E | LT |
| Changer d'arme (debout sur un sanctuaire) | haut | haut |
| Recommencer | R | View |
| Afficher / cacher l'aide | H | Menu |

## Les deux armes

On change d'arme sur les **sanctuaires**, les cercles de sel blancs (un au départ, un au
fond de l'arène).

**Marteau de Gerold : la Cadence.** Lent et lourd. À la fin de chaque coup, la tête du
marteau lance un **éclair blanc** et tinte : refrapper pendant cet éclair (environ un quart
de seconde) fait monter la Chaleur. L'anneau en bas de l'écran se referme pendant le coup et
s'allume en blanc au bon moment. Hors tempo, la Chaleur ne monte pas, mais rien n'est
perdu ; elle ne retombe qu'après deux secondes sans frapper.
- Trois paliers : *rougeoie* (+1 dégât, brûlure), *brise-garde* (les coups légers brisent le
  bouclier du soldat), *à blanc* : la frappe suivante est une **Frappe à blanc**, une explosion
  d'étincelles qui sonne la cloche. Après elle, la Chaleur retombe au palier brise-garde.
- **Trempe** : dans l'eau, dans une flaque de sang ou à côté d'un soldat à terre, `E`
  refroidit l'arme d'un coup et donne 3 s de vitesse.
- L'attaque lourde chargée brise les gardes et le mur fissuré.

**Pics de mineur : l'Entaille.** Deux pics rapides. Chaque coup ouvre une plaie (petits
traits rouges au-dessus de la cible) ; au **cinquième coup** sur la même cible, elle saigne
fort. Les coups en l'air retiennent la chute, l'attaque lourde est un bond qui frappe vers
le haut, et contre un mur, les Pics freinent la glissade : on peut sauter de mur en mur.

## Le reste à essayer

- **Le soldat.** Il avance bouclier levé (le frapper finit par fendre le bouclier), prévient
  avant son coup de lance (contour rouge, « ! »), puis reste ouvert. Les coups légers
  n'interrompent pas son attaque : il faut esquiver ou contrer. Un contre réussi ou une garde
  brisée le met **à terre**. Il réapparaît 6 s après sa mort.
- **Rage et Panser.** La Rage monte en frappant et en étant blessé. `F` dépense 33 de Rage
  pour rendre 3 PV après une seconde immobile ; un coup pendant ce temps gâche le bandage.
- **Le parcours.** Glissade sous le passage bas, pics au sol (on peut rebondir dessus avec
  une frappe vers le bas), mur fissuré à briser avec une attaque lourde chargée du Marteau.

## Régler les sensations

Tous les réglages sont en haut des scripts, avec des commentaires :

- `scripts/player.gd` : vitesse, saut, ruée, Cadence (`cadence_window`, `heat_grace`,
  `heat_after_blanc`), Pics (bond, glissade au mur), Rage, Panser, fenêtre de contre.
- `scripts/soldier.gd` : vie, vitesse, durée du signal d'attaque, bouclier.
- `scripts/main.gd` : le niveau, dessiné en caractères (`#` bloc, `X` mur fragile,
  `^` pics, `~` eau, `S` sanctuaire, `E` soldat, `D` mannequin, `P` départ).

## Test automatique

```
godot --headless res://tests/smoke_test.tscn
```

Pilote Wendel avec de fausses touches et vérifie déplacements, Cadence, Frappe à blanc,
trempe, parcours, soldat, contre, Panser, changement d'arme, Entaille et glissade au mur.

Fan-game privé, non commercial, d'après *Berserk* de Kentaro Miura.
