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
	p._start_attack(0, false)
	var t0 := p._state_time
	var n := 0
	for at in [0.03, 0.08, 0.11, 0.15, 0.2, 0.3, 0.38]:
		while p._state_time < at and p.state == Player.S.ATTACK:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out + "/attaque_%d.png" % n)
		n += 1
	Engine.time_scale = 1.0
	get_tree().quit()
