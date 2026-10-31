extends Node
## Test automatique du Contremaître, sans écran : godot --headless res://tests/boss_test.tscn
## Entrée par le puits, réveil, visages, pioche et ondes, effondrement, deuxième phase, mort,
## et remontée dans le Grand Puits.

var game: Game
var p: Player
var fails := 0


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(World.SAVE_PATH))
	Game.debug_room = "h21_carreau"
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


func _boss() -> Contremaitre:
	for n in game.room.get_children():
		if n is Contremaitre:
			return n
	return null


func _hit(b: Contremaitre, rect: Rect2, dmg: int) -> String:
	return b.take_hit({"damage": dmg, "source_x": rect.get_center().x, "dir": Vector2(1, 0), "burn": false,
		"guard_break": false, "heavy": false, "charge": 0.0, "blanc": false, "rect": rect})


func _run() -> void:
	# La grille pourrie du puits cède à l'attaque lourde chargée, et on tombe dans la fosse.
	await _wait(0.2)
	p.position = _cell(99, 18)
	p.velocity = Vector2.ZERO
	for e in game.room.get_children().filter(func(n): return n is Soldier):
		e.queue_free()
	p.facing = 1
	await _wait(0.4)
	Input.action_press("lourde")
	await _wait(0.75)
	Input.action_release("lourde")
	await _wait(0.4)
	_check(get_tree().get_nodes_in_group("fragile").is_empty(), "l'attaque lourde brise la grille du puits")
	for i in 600:
		await get_tree().physics_frame
		if game.room.id == "h19_fosse":
			break
	await _wait(2.0)
	var b := _boss()
	_check(game.room.id == "h19_fosse" and b != null, "on tombe par le Grand Puits dans la fosse du Contremaître")
	if b == null:
		return
	_check(b.is_engaged() and game.doors_locked and game.boss == b, "il s'éveille quand Wendel touche le sol, la fosse se ferme")
	p.hp = 99
	p.max_hp = 99
	await _wait(1.8)

	# La masse encaisse ; les visages qui pleurent, non.
	b.faces_open = [false, false, false]
	b._face_timer = 99.0
	var hp0 := b.hp
	_hit(b, Rect2(b.position - Vector2(10, 10), Vector2(20, 20)), 3)
	_check(b.hp == hp0, "frapper la masse ne lui fait presque rien (%d -> %d)" % [hp0, b.hp])
	b.faces_open = [true, false, false]
	var face := b._face_rect(0)
	_hit(b, face, 3)
	_check(b.hp == hp0 - 3, "frapper un visage qui pleure le blesse (%d -> %d)" % [hp0, b.hp])
	b.faces_open = [false, false, false]
	b._face_timer = 1.0

	# Le coup de pioche lance des ondes au sol, qui blessent.
	b._go(Contremaitre.S.SLAM_WIND)
	await _wait(0.9)
	var waves := game.room.get_children().filter(func(n): return n is BossHazard and n.kind == "onde")
	_check(waves.size() == 2, "le coup de pioche lance deux ondes au sol (%d)" % waves.size())
	var w: BossHazard = waves[0] if waves.size() > 0 else null
	if w:
		p._invuln = 0.0
		var php := p.hp
		p.position = w.position + Vector2(signf(w.velocity.x) * 60.0, -12.0)
		p.velocity = Vector2.ZERO
		for i in 120:
			await get_tree().physics_frame
			if p.hp < php:
				break
		_check(p.hp < php, "une onde blesse Wendel s'il ne saute pas")
	await _wait(1.0)

	# Les lanternes laissent du feu au sol.
	p.position = b.position + Vector2(-400, 60)
	p._invuln = 0.0
	b._go(Contremaitre.S.THROW_WIND)
	var fire := false
	for i in 300:
		await get_tree().physics_frame
		if game.room.get_children().any(func(n): return n is BossHazard and n.kind == "feu"):
			fire = true
			break
	_check(fire, "une lanterne lancée laisse une flaque de feu")
	await _wait(0.8)

	# L'effondrement : la masse roule vers Wendel, puis repousse tous visages ouverts.
	var x0 := b.position.x
	p.position = Vector2(b.position.x - 500, p.position.y)
	b._go(Contremaitre.S.SHUDDER)
	await _wait(1.3)
	_check(b.state == Contremaitre.S.COLLAPSE and absf(b.position.x - x0) > 60.0, "la masse s'effondre et roule vers Wendel")
	for i in 400:
		await get_tree().physics_frame
		if b.state == Contremaitre.S.REFORM:
			break
	await get_tree().physics_frame
	_check(b.state == Contremaitre.S.REFORM and b.faces_open == [true, true, true], "en repoussant, tous ses visages s'ouvrent")
	var hp1 := b.hp
	_hit(b, b._face_rect(1), 4)
	_check(b.hp == hp1 - 6, "et ils prennent plus cher (%d -> %d)" % [hp1, b.hp])

	# Deuxième phase sous la moitié de sa vie
	await _wait(1.5)
	b.hp = b.max_hp / 2 + 1
	b.faces_open = [true, false, false]
	_hit(b, b._face_rect(0), 2)
	_check(b.phase == 2, "sous la moitié de sa vie, les visages hurlent (phase 2)")
	b.faces_open = [false, false, false]
	b._face_timer = 0.0
	b._go(Contremaitre.S.WALK)
	await _wait(0.1)
	_check(b.faces_open.count(true) == 2, "deux visages s'ouvrent à la fois")
	b._go(Contremaitre.S.SLAM_WIND)
	await _wait(0.8)
	_check(game.room.get_children().any(func(n): return n is Rampant), "un mineur rampant se détache de la masse")

	# Mort
	var scrap0 := World.scrap
	b.hp = 1
	b.faces_open = [true, true, true]
	_hit(b, b._face_rect(2), 3)
	await _wait(3.0)
	_check(World.flags.has("boss:contremaitre") and not game.doors_locked and World.scrap == scrap0 + 60,
		"vaincu, il laisse 60 ferraille et rouvre la fosse")
	_check(game.mode == Game.M.TEXT and "Ilse" in game.text_body, "Wendel reconnaît des visages")
	for i in 600:
		if game._text_since > 0.3:
			break
		await get_tree().process_frame
	await _tap_ui("saut")
	await _wait(0.2)

	# On remonte par les échafaudages, dans le Grand Puits
	p.max_hp = 7
	p.hp = 7
	p.position = _cell(61, 4)
	p.velocity = Vector2.ZERO
	await _wait(0.4)
	Input.action_press("saut")
	for i in 120:
		await get_tree().physics_frame
		if game.room.id == "h23_grand_puits":
			break
	Input.action_release("saut")
	Input.action_press("droite")
	await _wait(0.6)
	Input.action_release("droite")
	await _wait(0.8)
	_check(game.room.id == "h23_grand_puits" and p.is_on_floor() and p.position.y < 59 * 32,
		"on remonte de la fosse sur l'échafaudage du Grand Puits (y=%.0f)" % p.position.y)

	# Le boss vaincu ne revient pas
	game._load_room("h19_fosse", _cell(10, 40))
	await _wait(0.3)
	_check(_boss() == null, "le Contremaître vaincu ne revient pas")
