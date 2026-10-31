extends Node
## Test automatique du monde, sans écran : godot --headless res://tests/world_test.tscn
## Nouvelle partie dans les galeries de Hautfer : passages, repos, nuit, esprits, brume, treuil,
## mort et ombre de marqué, marteau de Gerold, mur fissuré, sauvegarde.

var game: Game
var p: Player
var fails := 0


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(World.SAVE_PATH))
	Game.debug_room = ""
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	await _run()
	print("=== %s (%d échec(s)) ===" % ["OK" if fails == 0 else "ÉCHEC", fails])
	get_tree().quit(1 if fails else 0)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _tap(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)


## Ferme le texte affiché (lettre, objet) une fois qu'il est lisible.
func _close_text() -> void:
	for i in 600:
		if game._text_since > 0.3:
			break
		await get_tree().process_frame
	await _tap_ui("saut")


func _tap_ui(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	await get_tree().process_frame
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)
	await get_tree().process_frame


func _cell(x: int, y: int) -> Vector2:
	return Vector2(x * 32 + 16, y * 32 + 4)


func _find(type) -> Array:
	return game.room.get_children().filter(func(n): return is_instance_of(n, type))


func _run() -> void:
	# Toutes les salles : chaque passage mène à un passage qui existe.
	var bad := []
	for id in Rooms.DATA:
		for digit in Rooms.DATA[id].doors:
			var dest: Array = Rooms.DATA[id].doors[digit]
			var ok: bool = Rooms.DATA.has(dest[0]) and dest[1] in Rooms.DATA[dest[0]].rows.reduce(func(acc, r): return acc + r, "")
			var back: Array = Rooms.DATA.get(dest[0], {}).get("doors", {}).get(dest[1], [])
			if not ok or back != [id, digit]:
				bad.append("%s:%s" % [id, digit])
	_check(bad.is_empty(), "les passages entre salles vont dans les deux sens %s" % str(bad))

	_check(game.mode == Game.M.TITLE, "l'écran titre s'affiche")
	game.new_game()
	p = game.player
	await _wait(0.4)
	_check(game.mode == Game.M.TEXT, "la nouvelle partie s'ouvre sur un texte")
	await _close_text()
	await _wait(0.5)
	_check(game.mode == Game.M.PLAY and game.room.id == "h01_effondrement" and p.is_on_floor(),
		"Wendel se réveille dans la mine effondrée")
	_check(p.weapon_name(p.weapon) == "Masse brisée", "il n'a que la masse brisée")

	# Ni attaque lourde ni ruée avant de les avoir trouvées.
	Input.action_press("lourde")
	await _wait(0.3)
	Input.action_release("lourde")
	_check(p.state != Player.S.CHARGE, "pas d'attaque lourde avec la masse brisée")
	await _wait(0.3)
	await _tap("ruee")
	await get_tree().physics_frame
	_check(p.state != Player.S.DASH, "pas de Ruée avant la Lande")

	# Glissade sous l'éboulis
	p.position = _cell(41, 18)
	p.facing = 1
	await _wait(0.3)
	Input.action_press("droite")
	await _tap("glissade")
	await _wait(0.7)
	Input.action_release("droite")
	await _wait(0.8)
	_check(p.position.x > 49 * 32, "la glissade passe sous l'éboulis (x=%.0f)" % p.position.x)

	# Passage vers la galerie des corps
	for r in _find(Rampant):
		r.queue_free()
	p.position = _cell(72, 18)
	await _wait(0.2)
	Input.action_press("droite")
	for i in 120:
		await get_tree().physics_frame
		if game.room.id == "h02_corps":
			break
	Input.action_release("droite")
	await _wait(0.6)
	_check(game.room.id == "h02_corps" and p.position.x < 6 * 32, "le passage mène à la galerie des corps")

	# Le treuil du puits, sur la place, se traverse par dessous
	game._load_room("h15_place", _cell(64, 18))
	await _wait(0.5)
	var y0 := p.position.y
	p.velocity.y = -820.0   # un élan comme celui d'un trou dans le sol
	await _wait(1.0)
	_check(p.is_on_floor() and p.position.y < y0 - 2 * 32, "on monte sur le treuil en sautant à travers (%.0f -> %.0f)" % [y0, p.position.y])

	# Repos au brasier de la lampisterie : sauvegarde
	game._load_room("h03_lampisterie", _cell(20, 106))
	await _wait(0.2)
	for r in _find(Rampant):
		r.queue_free()
	p.position = _cell(20, 106)
	await _wait(0.4)
	await _tap("haut")
	await _wait(0.05)
	_check(game.mode == Game.M.REST and World.rest_room == "h03_lampisterie" and World.has_save(),
		"le brasier sauvegarde la partie")

	# Attendre la nuit depuis le menu
	game.menu_index = 0
	await _tap_ui("saut")
	await _wait(1.0)
	_check(World.is_night() and game.mode == Game.M.PLAY, "on peut attendre la nuit au repos")

	# La nuit, les esprits viennent
	p.hp = 99
	p.max_hp = 99
	p.position = _cell(10, 106)
	game._spawn_timer = 0.0
	await _wait(0.3)
	var spirits := _find(Spirit).filter(func(s): return not s.daylight)
	_check(not spirits.is_empty(), "la nuit, des esprits apparaissent (%d)" % spirits.size())
	var hp_before := p.hp
	for i in 1800:
		await get_tree().physics_frame
		if p.hp < hp_before:
			break
	_check(p.hp < hp_before, "un esprit fond sur Wendel et le blesse")
	# On peut le frapper
	var s: Spirit = _find(Spirit).filter(func(n): return not n.daylight)[0]
	var shp := s.hp
	s.take_hit({"damage": 1, "source_x": s.position.x - 10, "dir": Vector2(1, 0), "burn": false,
		"guard_break": false, "heavy": false, "charge": 0.0, "blanc": false})
	_check(s.hp < shp, "un esprit peut être frappé")

	# À l'aube, ils se dissolvent
	World.wait_until(false)
	await _wait(1.3)
	spirits = _find(Spirit).filter(func(n): return not n.daylight)
	_check(spirits.is_empty(), "à l'aube, les esprits se dissolvent")

	# La brume de la galerie de roulage : solide la nuit seulement
	game._load_room("h06_roulage", _cell(28, 13))
	await _wait(0.6)
	_check(p.position.y > 17 * 32, "le jour, on traverse la brume (y=%.0f)" % p.position.y)
	World.wait_until(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	p.position = _cell(28, 13)
	p.velocity = Vector2.ZERO
	await _wait(0.6)
	_check(p.is_on_floor() and absf(p.position.y - (16 * 32 - 28)) < 4.0, "la nuit, la brume porte Wendel (y=%.0f)" % p.position.y)
	World.wait_until(false)
	await _wait(1.2)

	# Le marteau de Gerold, à la forge
	game._load_room("h13_forge", _cell(10, 18))
	await _wait(0.3)
	p.position = _cell(19, 15)
	await _wait(0.2)
	_check(World.has("lourde") and game.mode == Game.M.TEXT, "le marteau de Gerold se ramasse sur l'enclume")
	await _close_text()
	await _wait(0.2)
	_check(p.weapon_name(p.weapon) == "Marteau de Gerold", "la masse brisée laisse place au marteau")

	# Le mur éboulé cède à l'attaque lourde chargée, et le reste
	for r in _find(Rampant):
		r.queue_free()
	game._load_room("h04_etais", _cell(12, 18))
	for r in _find(Rampant):
		r.queue_free()
	await _wait(0.2)
	p.facing = -1
	await _wait(0.4)
	Input.action_press("lourde")
	await _wait(0.75)
	Input.action_release("lourde")
	await _wait(0.5)
	_check(get_tree().get_nodes_in_group("fragile").is_empty(), "l'attaque lourde chargée brise le mur éboulé")
	game._load_room("h04_etais", _cell(30, 18))
	await _wait(0.2)
	_check(get_tree().get_nodes_in_group("fragile").is_empty(), "un mur brisé le reste en revenant")

	# La lettre d'Ilse
	game._load_room("h14_maison", _cell(14, 18))
	await _wait(0.2)
	p.position = _cell(8, 18)
	await _wait(0.3)
	_check(1 in World.letters and game.mode == Game.M.TEXT, "la lettre d'Ilse se lit dans sa chambre")
	await _close_text()
	await _wait(0.2)

	# Mort : la ferraille reste, gardée par l'ombre de marqué
	p.max_hp = 7
	p.hp = 1
	World.scrap = 40
	game._load_room("h15_place", _cell(30, 18))
	for e in _find(Soldier):
		e.queue_free()
	await _wait(0.4)
	p._hurt(1, p.position + Vector2(-20, 0), true)
	await _wait(2.6)
	_check(game.room.id == "h03_lampisterie" and not p.is_dead() and p.hp == p.max_hp,
		"après la mort, Wendel se réveille au dernier repos")
	_check(World.scrap == 0 and World.shadow.get("amount", 0) == 40 and World.shadow.room == "h15_place",
		"la ferraille reste là où il est tombé")
	game._load_room("h15_place", _cell(20, 18))
	await _wait(0.2)
	var shadows := _find(MarkedShadow)
	_check(shadows.size() == 1, "son ombre de marqué l'attend")
	if shadows.size() == 1:
		var sh: MarkedShadow = shadows[0]
		sh.take_hit({"damage": 99, "source_x": sh.position.x - 10, "dir": Vector2(1, 0), "burn": false,
			"guard_break": false, "heavy": false, "charge": 0.0, "blanc": false})
		await _wait(0.1)
		_check(World.scrap == 40 and World.shadow.is_empty(), "vaincre l'ombre rend la ferraille")

	# La sauvegarde se recharge
	World.save_game()
	var had := World.has("lourde")
	World.new_game()
	_check(World.load_game() and World.has("lourde") == had and World.rest_room == "h03_lampisterie" and 1 in World.letters,
		"la sauvegarde se recharge (capacités, repos, lettres)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(World.SAVE_PATH))
