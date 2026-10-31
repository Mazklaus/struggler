class_name Rooms
extends RefCounted
## Les salles du jeu, dessinées en caractères (une case = 32 pixels).
##
## Légende :
##   #  roche                 X  mur fissuré (attaque lourde chargée du marteau de Gerold)
##   ^  pics, étais brisés    ~  eau (trempe)              w  margelle de puits (roche)
##   =  brume figée : une plateforme qui n'existe que la nuit (on la traverse par dessous)
##   S  cercle de sel : repos, sauvegarde, change d'arme ; les esprits n'y entrent pas
##   F  brasier : repos et sauvegarde, mais il ne protège pas des esprits
##   1-9  passage vers une autre salle (voir "doors" : chiffre -> [salle, chiffre d'arrivée])
##   b  bois plein   M  maçonnerie   o  chair   t  éboulis, déblais   a  fer   (blocs pleins : la matière
##      n'est qu'une indication de DA pour le dessin gris ; "labels" dit ce que représentent les volumes)
##   -  bois (treuil, poutre, tribune) : une plateforme qu'on traverse par dessous (toujours là)
##   P  départ d'une nouvelle partie   R  mineur rampant   E  soldat   D  mannequin
##   G  point d'apparition des esprits la nuit      g  esprit présent même le jour
##   c  corps (décor)            B  boss de la salle (voir "boss"), absent une fois vaincu
##   Objets (voir ITEMS) : f ferraille, v bandage de Hautfer (+1 PV), m marteau de Gerold,
##   l lettre d'Ilse, k les pics des mineurs.
##
## Les salles de Hautfer sont dans rooms_hautfer.gd (généré par tools/gen_hautfer.py).
##
## "hints" : panneaux d'aide posés dans la salle, [colonne, ligne, texte].

const START_ROOM := "h01_effondrement"
const TEST_ROOM := "essai"

## Objets ramassables : ce qu'ils donnent et le texte affiché.
const ITEMS := {
	"f": {"type": "ferraille", "amount": 25},
	"v": {"type": "pv", "title": "Bandage de Hautfer",
		"text": "Une bande de lin brodée d'un H. Ilse en cousait pour les mineurs.\n\n+1 point de vie maximum."},
	"m": {"type": "capacite", "id": "lourde", "title": "Le marteau de Gerold",
		"text": "Le marteau de ton père, encore posé sur l'enclume froide.\nIl répétait que tu avais pris toute la force.\n\nAttaque lourde : maintenir K (Y), relâcher. Chargée, elle brise les murs fissurés.\nLa Cadence : refrappe pendant l'éclair blanc pour faire chauffer le marteau."},
	"k": {"type": "capacite", "id": "pics_mineurs", "title": "Les pics des mineurs",
		"text": "Les pics de ceux qui sont morts au fond, rangés au râtelier comme chaque soir.\nTu les emportes. Avec un peu de sel et une bonne forge, ils serviront encore."},
	"l": {"type": "lettre", "id": 1, "title": "Lettre d'Ilse, jamais envoyée",
		"text": "Wendel,\n\nTu es parti avant l'aube pour ne pas me voir pleurer.\nJe t'ai vu quand même, par la fenêtre.\n\nIlse"},
}

const BASE := {
	"essai": {
		"name": "Salle d'essai",
		"zone": "Prototype",
		"doors": {},
		"hints": [
			[6, 11, "Refrappe (J) pendant l'éclair blanc du marteau : la Cadence le fait chauffer"],
			[2, 13, "Sanctuaire : haut pour se reposer, changer d'arme"],
			[19, 14, "Trempe (E) dans l'eau : refroidit l'arme, bonus de vitesse"],
			[49, 8, "Glissade (C) sous le passage bas"],
			[55, 12, "Ruée (Maj ou L) par-dessus les pics,"],
			[55, 13, "ou frappe vers le bas dessus pour rebondir"],
			[59, 8, "Attaque lourde : maintenir K, relâcher"],
			[73, 7, "Contre (I) juste avant le coup de lance"],
			[73, 8, "Panser (F) : 33 de Rage = 3 PV"],
		],
		"rows": [
		"################################################################################################################",
		"#                                                                    ##                                        #",
		"#                                                                    ##                                        #",
		"#                                                                    ##                                        #",
		"#                                                                    ##                                        #",
		"#                                                                    ##                                        #",
		"#                                                                    ##                                        #",
		"#                                                                    ##                                        #",
		"#                                      ######                        ##                                        #",
		"#                                                                    ##                           E            #",
		"#                                             ########               XX                          ####          #",
		"#                                ####         ########               XX                                        #",
		"#                                             ########               XX                                        #",
		"#                                             ########               XX             #####                      #",
		"#                          ####               ########               XX                                        #",
		"#                                             ########               XX                                        #",
		"#  P S     D                                                         XX          E           E          S      #",
		"##################~~~~###################################        ##########~~~##################################",
		"#########################################################^^^^^^^^###############################################",
		"################################################################################################################",
		"################################################################################################################",
		],
	},
}


## Toutes les salles du jeu : la salle d'essai et les zones.
static var DATA := _all()


static func _all() -> Dictionary:
	var d := BASE.duplicate()
	d.merge(RoomsHautfer.DATA)
	return d
