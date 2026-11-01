extends Node
## Test automatique de la Lande aux Pendus, sans écran : godot --headless res://tests/lande_test.tscn
## Première nuit et chevalier noir, Corvin et ses étapes, sacs de sel, épreuve des tranchées,
## Ruée, herse du sentier des pendus, Seigneur des gibets.

var game: Game
var p: Player
var fails := 0


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(World.SAVE_PATH))
	Game.debug_room = "l04_corbeaux"
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	p = game.player
	await _run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(World.SAVE_PATH))
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


func _close_text() -> void:
	for i in 600:
		if game.mode == Game.M.TEXT and game._text_since > 0.3:
			break
		await get_tree().process_frame
	await _tap_ui("saut")
	await _wait(0.1)


func _cell(x: int, y: int) -> Vector2:
	return Vector2(x * 32 + 16, y * 32 + 4)


func _goto(room_id: String, x: int, y: int) -> void:
	game._load_room(room_id, Vector2.ZERO)
	p.position = _cell(x, y)
	p.velocity = Vector2.ZERO
	p.reset_safe_pos()
	await _wait(0.3)


func _clear_enemies() -> void:
	for n in game.room.get_children():
		if n is Soldier or n is Crow or n is Spirit or n is Rampant:
			n.queue_free()
	await get_tree().physics_frame


func _talk_to(x: int, y: int) -> void:
	p.position = _cell(x, y)
	p.velocity = Vector2.ZERO
	await _wait(0.3)
	await _tap("haut")
	await _close_text()


func _run() -> void:
	await _wait(0.3)
	# la salle de départ de débogage donne tout : on repart des capacités de la fin de Hautfer
	World.abilities = {"lourde": true}
	World.weapons = [0]
	World.grant("pics_mineurs")
	World.wait_until(false)

	# --- La première nuit : elle tombe d'un coup, les spectres submergent Wendel, le chevalier noir.
	await _goto("l05_lande", 30, 18)
	await _clear_enemies()
	p.max_hp = 7
	p.hp = 7
	p.position = _cell(50, 18)
	await _wait(0.5)
	var spirits := game.room.get_children().filter(func(n): return n is Spirit).size()
	_check(World.is_night() and spirits >= 8, "la nuit tombe d'un coup sur la lande (%d esprits)" % spirits)
	_check(game.mercy, "pendant la scène, Wendel ne peut pas mourir")
	p.hp = 1
	var knight_seen := false
	for i in 3600:
		await get_tree().physics_frame
		if is_instance_valid(game._knight):
			knight_seen = true
		if World.flags.has("premiere_nuit"):
			break
	_check(knight_seen, "un homme en armure noire surgit")
	_check(World.flags.has("premiere_nuit") and p.hp >= 1 and not p.is_dead(), "il taille les spectres et repart ; Wendel est vivant (pv %d, %s)" % [p.hp, game.event_time])
	await _close_text()
	_check(not game.mercy, "la scène finie, la mort redevient possible")
	World.wait_until(false)

	# --- Corvin : soin, cercles de sel, les Pics forgés, la tâche du sel.
	await _goto("l06_tour", 3, 62)
	p.hp = 2
	await _talk_to(8, 62)
	_check(World.flags.get("corvin", 0) == 1 and World.has("sel"), "Corvin apprend les cercles de sel (étape 1)")
	_check(p.hp == p.max_hp, "Corvin soigne Wendel")
	_check(1 in World.weapons, "Corvin forge les pics des mineurs")
	_check(not World.has("ruee"), "pas encore de Ruée")
	await _talk_to(8, 62)
	_check(World.flags.get("corvin", 0) == 1, "sans le sel, Corvin attend")

	# --- Le moulin : les sacs de sel volés, le paysan en cage.
	await _goto("l10_moulin", 76, 18)
	await _clear_enemies()
	var sergeant := false
	game._load_room("l10_moulin", Vector2.ZERO)
	for n in game.room.get_children():
		if n is Soldier and n.sergeant:
			sergeant = true
	_check(sergeant, "un sergent garde le camp des déserteurs")
	await _clear_enemies()
	p.position = _cell(78, 18)
	await _wait(0.2)
	p.position = _cell(80, 18)
	for i in 120:
		await get_tree().physics_frame
		if World.flags.has("quete:sel_corvin"):
			break
	_check(World.flags.has("quete:sel_corvin"), "on reprend les sacs de sel de Corvin")
	await _close_text()
	await _talk_to(15, 18)
	_check(World.flags.has("refugie:paysan"), "on libère le paysan de sa cage")

	await _goto("l06_tour", 3, 62)
	await _talk_to(8, 62)
	_check(World.flags.get("corvin", 0) == 2, "Corvin envoie Wendel aux tranchées (étape 2)")

	# --- L'épreuve : une nuit entière dans le cercle des tranchées.
	await _goto("l09_tranchees", 70, 20)
	await _clear_enemies()
	await _tap("haut")
	await _wait(0.3)
	var has_trial := game.menu_items.any(func(it): return it[0] == "epreuve")
	_check(has_trial, "le cercle des tranchées propose l'épreuve")
	game._rest_choice("epreuve")
	game.mode = Game.M.PLAY
	get_tree().paused = false
	await _wait(1.5)
	_check(game.trial_time > 0.0 and World.is_night() and game.doors_locked, "la nuit de l'épreuve commence, les passages se ferment")
	p.max_hp = 99
	p.hp = 99
	await _wait(3.0)
	var many := game.room.get_children().filter(func(n): return n is Spirit).size()
	_check(many >= 2, "les esprits affluent autour du cercle (%d)" % many)
	game.trial_time = 0.3
	await _wait(0.6)
	_check(World.flags.has("epreuve") and not World.is_night(), "à l'aube, l'épreuve est réussie")
	await _goto("l06_tour", 3, 62)
	await _talk_to(8, 62)
	_check(World.flags.get("corvin", 0) == 3 and World.has("ruee"), "Corvin apprend la Ruée (étape 3)")

	# --- La herse : sans la Ruée, le fossé est trop large ; avec, on passe avant qu'elle retombe.
	await _goto("l19_sentier", 25, 13)
	_check(not await _herse_run(false), "sans la Ruée, on ne passe pas le fossé")
	await _goto("l19_sentier", 25, 13)
	await _wait(1.0)
	_check(await _herse_run(true), "avec la Ruée, on passe sous la herse avant qu'elle retombe")

	# --- Le Seigneur des gibets.
	await _goto("l17_grand_gibet", 30, 40)
	await _clear_enemies()
	p.max_hp = 99
	p.hp = 99
	var b: SeigneurGibets = null
	for n in game.room.get_children():
		if n is SeigneurGibets:
			b = n
	_check(b != null, "le Seigneur des gibets attend sous le chêne")
	if b == null:
		return
	for i in 120:
		await get_tree().physics_frame
		if b.is_engaged():
			break
	_check(b.is_engaged() and game.doors_locked, "il s'éveille, le gibet se ferme")
	await _wait(2.0)
	b._go(SeigneurGibets.S.NOOSE_WIND)
	await _wait(0.7)
	var nooses := game.room.get_children().filter(func(n): return n is BossHazard and n.kind == "noeud").size()
	_check(nooses >= 3, "il fait tomber des nœuds coulants (%d)" % nooses)
	await _wait(1.5)
	b._go(SeigneurGibets.S.LEAP)
	var perched := false
	var landed := false
	for i in 400:
		await get_tree().physics_frame
		if b.state == SeigneurGibets.S.PERCH:
			perched = true
		if perched and b.state == SeigneurGibets.S.DROP_REC:
			landed = true
			break
	_check(perched and landed, "il bondit dans les branches et retombe sur Wendel")
	await _wait(1.0)
	b.take_hit({"damage": b.hp - b.max_hp / 2 + 1, "source_x": b.position.x - 40, "dir": Vector2(1, 0), "burn": false,
		"guard_break": false, "heavy": false, "charge": 0.0, "blanc": false, "rect": Rect2(b.position, Vector2(10, 10))})
	_check(b.phase == 2, "sous la moitié de sa vie, les pendus se détachent (phase 2)")
	var fell := false
	for i in 900:
		await get_tree().physics_frame
		if game.room.get_children().any(func(n): return n is BossHazard and n.kind == "pendu"):
			fell = true
			break
	_check(fell, "les pendus tombent des branches")
	for k in 40:
		if b.dead:
			break
		b.take_hit({"damage": 5, "source_x": b.position.x - 40, "dir": Vector2(1, 0), "burn": false,
			"guard_break": false, "heavy": false, "charge": 0.0, "blanc": false, "rect": Rect2(b.position, Vector2(10, 10))})
		await _wait(0.05)
	for i in 400:
		await get_tree().physics_frame
		if World.flags.has("boss:gibets"):
			break
	_check(World.flags.has("boss:gibets") and not game.doors_locked, "vaincu, le gibet se rouvre")
	await _close_text()
	await _goto("l17_grand_gibet", 30, 40)
	_check(not game.room.get_children().any(func(n): return n is SeigneurGibets), "le Seigneur des gibets vaincu ne revient pas")
	await _goto("l19_sentier", 8, 13)
	await _wait(0.3)
	_check(game.room.herse.is_open(), "la herse reste levée")


## Tire la chaîne, puis court vers l'ouest : saut au bord du fossé, Ruée en l'air si on l'a.
func _herse_run(with_ruee: bool) -> bool:
	if not with_ruee:
		World.abilities.erase("ruee")
	await _clear_enemies()
	p.position = _cell(26, 13)
	p.velocity = Vector2.ZERO
	p.facing = -1
	await _wait(0.4)
	await _tap("haut")
	var opened: bool = game.room.herse._timer > 0.0
	Input.action_press("gauche")
	for i in 60:
		await get_tree().physics_frame
		if p.position.x < 23 * 32 + 8:
			break
	Input.action_press("saut")
	await _wait(0.3)   # la Ruée au sommet du saut porte le plus loin
	await _tap("ruee")
	await _wait(0.5)
	Input.action_release("saut")
	await _wait(0.6)
	Input.action_release("gauche")
	await _wait(0.3)
	var through := p.position.x < 13 * 32
	if not with_ruee:
		World.grant("ruee")
	return opened and through
