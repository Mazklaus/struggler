extends Node
## Test automatique sans écran : godot --headless res://tests/smoke_test.tscn
## Pilote Wendel avec de fausses touches et vérifie les systèmes principaux.

var game: Game
var p: Player
var fails := 0


func _ready() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	p = game.player
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


func _run() -> void:
	await _wait(0.6)
	_check(p.is_on_floor(), "Wendel est posé au sol")

	# Course
	var x0 := p.position.x
	Input.action_press("droite")
	await _wait(0.5)
	Input.action_release("droite")
	_check(p.position.x - x0 > 80.0, "la course avance (%.0f px)" % (p.position.x - x0))
	await _wait(0.3)

	# Saut
	var y0 := p.position.y
	Input.action_press("saut")
	await _wait(0.3)
	_check(y0 - p.position.y > 60.0, "le saut monte (%.0f px)" % (y0 - p.position.y))
	Input.action_release("saut")
	await _wait(0.8)

	# Cadence sur le mannequin
	p.position = Vector2(11 * 32 + 16 - 50, p.position.y)
	p.facing = 1
	await _wait(0.3)
	for i in 6:
		await _tap("attaque")
		await _wait(0.5 - 2.0 / 120.0)
		if i == 2:
			print("    chaleur après 3 frappes : %.0f" % p.heat)
	_check(p.streak >= 4 or p.heat == 0.0, "la Cadence s'enchaîne (série %d, chaleur %.0f)" % [p.streak, p.heat])
	await _wait(0.1)
	var heat_before := p.heat
	print("    chaleur avant la frappe suivante : %.0f" % heat_before)
	# On frappe trop tôt : le rythme casse.
	await _wait(1.0)
	await _tap("attaque")
	await _wait(0.25)
	await _tap("attaque")
	await _wait(0.5)
	_check(p.last_judgment == "Trop tôt" or p.streak == 0, "une frappe trop tôt casse le rythme (%s)" % p.last_judgment)

	# Monter à blanc
	p.heat = 95.0
	var saw_blanc := false
	for i in 3:
		await _tap("attaque")
		saw_blanc = saw_blanc or p._atk.get("blanc", false)
		await _wait(0.5 - 2.0 / 120.0)
	await _wait(0.1)
	print("    chaleur après la Frappe à blanc : %.0f" % p.heat)
	_check(saw_blanc and p.heat < 100.0 and p.heat_tier() >= 2, "la Frappe à blanc part et la Chaleur retombe au palier 2 (%.0f)" % p.heat)
	await _wait(1.0)

	# Trempe dans l'eau
	p.heat = 50.0
	p.position = Vector2(19 * 32, 16 * 32)
	await _wait(0.4)
	await _tap("trempe")
	await _wait(0.1)
	_check(p.heat == 0.0 and p.haste_left() > 0.0, "la trempe refroidit et accélère")
	await _wait(0.5)

	# Glissade sous le passage bas (colonnes 46 à 53)
	p.position = Vector2(44 * 32, 16 * 32 + 4)
	p.facing = 1
	await _wait(0.3)
	Input.action_press("droite")
	await _tap("glissade")
	await _wait(0.6)
	Input.action_release("droite")
	await _wait(0.6)
	_check(p.position.x > 50 * 32, "la glissade passe sous le bloc (x=%.0f)" % p.position.x)

	# Pics : blessent et renvoient au sol sûr
	var hp0 := p.hp
	p.position = Vector2(60 * 32, 17 * 32)
	await _wait(0.4)
	_check(p.hp < hp0, "les pics blessent (%d -> %d)" % [hp0, p.hp])
	await _wait(1.2)

	# Mur fragile : une frappe légère ne le casse pas, une lourde chargée oui
	p.hp = p.max_hp
	p.position = Vector2(67 * 32, 16 * 32 + 4)
	p.facing = 1
	await _wait(0.4)
	var walls := get_tree().get_nodes_in_group("fragile").size()
	Input.action_press("lourde")
	await _wait(0.75)
	Input.action_release("lourde")
	await _wait(0.5)
	_check(get_tree().get_nodes_in_group("fragile").size() < walls, "l'attaque lourde chargée brise le mur")

	# Soldat : laisser Wendel se faire toucher
	p.hp = p.max_hp
	p.rage = 0.0
	var soldier: Soldier
	for s in get_tree().get_nodes_in_group("hittable"):
		if s is Soldier:
			soldier = s
			break
	p.position = soldier.position + Vector2(-70, 0)
	p.facing = 1
	var hit := false
	for i in 400:
		await get_tree().physics_frame
		if p.hp < p.max_hp:
			hit = true
			break
	_check(hit, "le soldat attaque et touche Wendel (état %d)" % soldier.state)
	_check(p.rage > 0.0, "la Rage monte quand on est blessé (%.0f)" % p.rage)

	# Contre : attendre la frappe et contrer juste avant
	await _wait(1.5)
	var countered := false
	for i in 2400:
		await get_tree().physics_frame
		if p.state != Player.S.NORMAL or p._invuln > 0.0:
			continue
		if soldier.state == Soldier.S.CHASE:
			p.position = soldier.position + Vector2(-80, 0)
			p.facing = 1
		if soldier.state == Soldier.S.WINDUP and soldier._t > 0.42:
			await _tap("contre")
			await _wait(0.3)
			if soldier.state == Soldier.S.DOWN:
				countered = true
				break
	_check(countered, "le contre met le soldat à terre (état %d)" % soldier.state)

	# Panser
	p.position = Vector2(4 * 32, 16 * 32)
	await _wait(0.5)
	p.hp = 2
	p.rage = 50.0
	await _tap("panser")
	await _wait(1.2)
	_check(p.hp == 5 and p.rage < 20.0, "panser rend 3 PV contre 33 de Rage (pv %d, rage %.0f)" % [p.hp, p.rage])

	# Tuer un soldat à la lourde pour vérifier mort et flaque
	soldier.hp = 1
	soldier.guard_up = false
	soldier._go(Soldier.S.STAGGER)
	soldier.take_hit({"damage": 5, "source_x": soldier.position.x - 10, "dir": Vector2(1, 0), "burn": false,
		"guard_break": true, "heavy": true, "charge": 1.0, "blanc": false})
	await _wait(0.1)
	_check(soldier.state == Soldier.S.DEAD, "le soldat meurt")
	_check(get_tree().get_nodes_in_group("trempe").any(func(n): return n is BloodPool), "il laisse une flaque de sang pour la trempe")
