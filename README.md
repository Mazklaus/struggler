# Struggler — tranche verticale (blocs gris)

Fan-game *Struggler* (Godot 4.6), encore sans graphismes. Après le prototype de combat
(le **Marteau** et sa Cadence, les **Pics** et leur Entaille, **Rage** et **Panser**), on
construit la tranche verticale : le prologue, les galeries de Hautfer (Z1) et la Lande aux
Pendus (Z2), avec le cycle jour/nuit de la marque et les premiers boss.

Pour l'instant : **les galeries de Hautfer** (cinq salles reliées), le cycle de la marque,
les repos, la mort et l'ombre de marqué. Les boss et la Lande arrivent dans les prochaines
étapes.

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
| Se reposer (cercle de sel ou brasier) | haut | haut |
| Menus : choisir / valider / quitter | haut, bas / Espace ou J / F | stick / A ou X / B |
| Revenir à l'écran titre | R | View |
| Afficher / cacher l'aide | H | Menu |

## L'écran titre

- **Nouvelle partie** : Wendel se réveille dans la mine effondrée de Hautfer.
- **Continuer** : reprend au dernier repos (la partie se sauvegarde à chaque repos, à chaque
  objet important et à la mort).
- **Salle d'essai** : l'ancienne arène du prototype, avec les deux armes et toutes les
  capacités.

## Les galeries de Hautfer

Wendel se réveille sous les décombres, seul vivant parmi les corps du bourg. De la masse
d'armes ramassée à Doldrey, il ne reste qu'un **tronçon** : coups légers seulement, pas
d'attaque lourde ni de Cadence. Il n'a pas non plus la **Ruée**, qu'il retrouvera chez Corvin
dans la Lande. Il faut remonter vers la surface :

1. **La mine effondrée** : glisser sous l'éboulis. Un mur fissuré garde une niche.
2. **La galerie inondée** : bassins pour la trempe, étais brisés, un brasier pour se
   reposer, et une corniche trop lointaine pour un simple saut.
3. **Le grand puits** : on monte de corniche en corniche. Une niche n'est accessible que la
   nuit, quand la brume se fige.
4. **Les ruines de Hautfer** : la forge de Gerold et son **marteau** (attaque lourde, Cadence),
   la maison des jumeaux et la **première lettre d'Ilse**, un mur éboulé à briser, une
   corniche trop haute.
5. **La place de la cloche** : un cercle de sel, et la grille pourrie du puits (attaque
   lourde chargée).
6. **La fosse du Contremaître** : le premier boss (voir plus bas). Des corniches permettent
   de remonter par le puits une fois la fosse rouverte.

Chaque salle laisse des obstacles qu'on ne peut pas encore franchir (Ruée, escalade, nuit),
pour donner envie de revenir.

## Le Contremaître

L'amas des mineurs de Hautfer, fondus ensemble par le sacrifice. La masse encaisse presque
tout : il faut frapper **les visages qui pleurent** (un à la fois, puis deux).

- **Coup de pioche** (il lève la pioche, contour rouge) : frappe devant lui et lance une onde
  au sol des deux côtés. Sauter par-dessus.
- **Lanternes** : lancées en cloche, elles laissent une flaque de feu.
- **Effondrement** (il tremble) : la masse s'écroule et roule vers Wendel. Sauter ou monter
  sur une corniche. En repoussant, **tous ses visages s'ouvrent** et prennent plus cher.
- Sous la moitié de sa vie, les visages hurlent : tout va plus vite, deux visages s'ouvrent,
  et des mineurs rampants se détachent de la masse.

## Le cycle de la marque

- Une journée dure 12 minutes : **8 de jour, 4 de nuit**. L'horloge est en haut de l'écran.
- La nuit, la marque saigne au cou de Wendel et les **esprits** (vert-bleu) viennent :
  ils traversent les murs, se gonflent de lumière (le signal), puis fondent sur lui.
- La nuit fige aussi la **brume** : des plateformes spectrales apparaissent.
- À l'aube, les esprits se dissolvent.

## Repos, mort et ferraille

- **Cercle de sel** et **brasier** : haut pour s'asseoir. La vie remonte, la partie est
  sauvegardée, et on peut changer d'arme ou attendre la nuit (ou l'aube). Les esprits
  n'entrent pas dans le sel ; le feu, lui, ne les arrête pas.
- Les ennemis laissent de la **ferraille**.
- À la mort, Wendel se réveille au dernier repos. Sa ferraille reste là où il est tombé,
  gardée par son **ombre de marqué** : la vaincre la rend. Mourir avant de la reprendre la
  perd pour de bon.

## Les deux armes

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
- `scripts/rooms.gd` : les salles, dessinées en caractères (la légende est en haut du
  fichier), leurs passages, leurs panneaux et les objets (textes de la lettre et du marteau).
- `scripts/world.gd` : durée du jour et de la nuit (`day_length`, `night_length`).
- `scripts/main.gd` : nombre d'esprits par salle la nuit (`SPIRITS_PER_ROOM`).
- `scripts/rampant.gd`, `scripts/spirit.gd`, `scripts/shadow.gd` : les nouveaux ennemis.

## Tests automatiques

```
godot --headless res://tests/smoke_test.tscn
godot --headless res://tests/world_test.tscn
godot --headless res://tests/boss_test.tscn
```

Le premier pilote Wendel dans la salle d'essai : déplacements, Cadence, Frappe à blanc,
trempe, parcours, soldat, contre, Panser, repos et changement d'arme, Entaille, glissade au
mur. Le second joue une nouvelle partie : passages entre salles, repos et sauvegarde, nuit et
esprits, brume, marteau de Gerold, mur éboulé, lettre d'Ilse, mort et ombre de marqué. Le
troisième vérifie le Contremaître, de la grille du puits jusqu'à la remontée.

Fan-game privé, non commercial, d'après *Berserk* de Kentaro Miura.
