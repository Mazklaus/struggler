extends Node
## Captures d'une frappe du Marteau au ralenti (outil de DA, non lancé par les tests).
## xvfb-run godot --rendering-driver opengl3 res://tests/shots_attaque.tscn -- <dossier>

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	Game.debug_room = ""
	var game: Game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.new_game()
	await get_tree().create_timer(0.5).timeout
	game.mode = Game.M.PLAY
	get_tree().paused = false
	game._load_room("h21_carreau", Vector2(60 * 32, 18 * 32))
	await get_tree().create_timer(1.0).timeout
	Engine.time_scale = 0.05
	var p: Player = game.player
	p.facing = 1
	# Coup de côté, vers le haut, vers le bas en l'air, puis lourd chargé (dir 0, 1, 2, 3).
	# Un 2e argument choisit les coups : -- <dossier> 3
	var dirs := [0, 1, 2, 3]
	if OS.get_cmdline_user_args().size() > 1:
		dirs = [int(OS.get_cmdline_user_args()[1])]
	for dir in dirs:
		Engine.time_scale = 1.0
		if dir == 2:
			p.velocity = Vector2(0, -700)
			await get_tree().create_timer(0.12).timeout
		if dir == 3:
			p._set_state(Player.S.CHARGE)
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(out + "/attaque_3_charge.png")
			p._charge = 1.0
		Engine.time_scale = 0.05
		p._start_attack(dir, false)
		var n := 0
		for at in [0.03, 0.08, 0.11, 0.15, 0.2, 0.3, 0.38]:
			while p._state_time < at and p.state == Player.S.ATTACK:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(out + "/attaque_%d_%d.png" % [dir, n])
			n += 1
		Engine.time_scale = 1.0
		await get_tree().create_timer(0.6).timeout
	Engine.time_scale = 1.0
	get_tree().quit()
