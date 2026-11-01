class_name Dialogues
extends RefCounted
## Ce que disent les personnages, selon l'avancée de la partie (World.flags).
## talk() renvoie [titre, texte] et applique ce que la conversation donne (capacité, arme...).

## Étapes de Corvin : flags["corvin"] vaut 0 (pas rencontré), 1 (la tâche du sel),
## 2 (la nuit dans les tranchées), 3 (la Ruée apprise).
static func talk(id: String) -> Array:
	match id:
		"corvin":
			return _corvin()
		"berger":
			World.flags["refugie:berger"] = true
			return ["L'enfant berger",
				"« Vous êtes marqué, vous aussi ? Ça saigne pareil.\nN'ayez pas peur. Une bergère va venir.\nElle viendra chercher tout le monde, même ceux qui saignent.\nC'est ma mère qui l'a vue en rêve, avant de partir. »"]
		"paysan":
			World.flags["refugie:paysan"] = true
			return ["Un paysan dans une cage",
				"Wendel force la porte de la cage.\n\n« Ils m'ont gardé pour me pendre au Grand Gibet, comme les autres.\nLeur chef dit qu'il parle aux pendus, là-haut, la nuit.\nQue l'arbre lui répond. »"]
	return ["", ""]


static func _corvin() -> Array:
	var step: int = World.flags.get("corvin", 0)
	var forge := ""
	if World.has("pics_mineurs") and not 1 in World.weapons:
		World.weapons.append(1)
		forge = "\n\nIl regarde les pics des mineurs que tu portes.\n« Bon fer. Viens à l'enclume. »\nVous les reforgez ensemble, au sel et au feu : les Pics de mineur.\n(Change d'arme en te reposant à un cercle de sel.)"
	match step:
		0:
			World.flags["corvin"] = 1
			World.grant("sel")
			var p := Game.inst.player
			p.hp = p.max_hp
			return ["Corvin le Salé",
				"Un vieil homme en manteau blanchi de sel. Au cou, la même marque que toi.\n\n« Dix ans que je la porte. Tu as tenu une nuit dehors : t'as eu de la chance, ou quelqu'un t'a aidé.\nLe sel les tient à distance. Un cercle de sel, c'est un endroit où dormir.\nLa nuit, ils viennent au sang. Le jour, ils dorment. Compte les heures, toujours. »" + forge +
				"\n\n« Des déserteurs m'ont volé mon sel, au vieux moulin, à l'ouest des tranchées.\nRamène-le-moi. Sans sel, cette tour ne tiendra plus longtemps. »"]
		1:
			if World.flags.has("quete:sel_corvin"):
				World.flags["corvin"] = 2
				return ["Corvin le Salé",
					"Il pèse les sacs, en goûte une pincée.\n\n« C'est bien le mien. »" + forge +
					"\n\n« Maintenant, une nuit seul. Descends aux tranchées, sous la tour.\nTrace ton cercle, assieds-toi dedans, et attends l'aube sans en sortir.\nQuoi que tu entendes. Surtout si ce sont des voix que tu connais. »"]
			return ["Corvin le Salé", "« Le moulin, à l'ouest des tranchées. Mon sel. »" + forge]
		2:
			if World.flags.has("epreuve"):
				World.flags["corvin"] = 3
				World.grant("ruee")
				return ["Corvin le Salé",
					"« Tu es resté dans le cercle. Bien.\nMaintenant, apprends à en sortir. »\n\nIl te montre comment se jeter en avant, d'un coup, au ras du sol, comme un homme qui fuit.\n\nLa Ruée : Maj ou L (RB). Elle traverse les coups, et franchit ce qu'un saut ne franchit pas.\n\n« Le sentier des pendus, à l'ouest. La herse retombe vite.\nEt là-haut, il y a celui qui fait pendre. »" + forge]
			return ["Corvin le Salé", "« Les tranchées, sous la tour. Une nuit, dans ton cercle. »" + forge]
	return ["Corvin le Salé", "« Dix ans. Parfois je me demande pourquoi je compte encore. »" + forge]
