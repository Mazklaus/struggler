extends Node
## Captures d'écran de chaque salle (outil de développement, non lancé par les tests).
## xvfb-run godot --rendering-driver opengl3 res://tests/shots.tscn -- <dossier>

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	Game.debug_room = ""
	var game: Game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.new_game()
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(out + "/00_texte.png")
	game.mode = Game.M.PLAY
	get_tree().paused = false
	var spots := {
		"z1_effondrement": [Vector2(7, 17), Vector2(30, 8)],
		"z1_galerie": [Vector2(20, 17), Vector2(50, 9)],
		"z1_puits": [Vector2(10, 38), Vector2(15, 24), Vector2(30, 6)],
		"z1_bourg": [Vector2(16, 17), Vector2(42, 11), Vector2(66, 17)],
		"z1_cloche": [Vector2(10, 17), Vector2(30, 17)],
	}
	var n := 1
	for id in spots:
		for c in spots[id]:
			game._load_room(id, Vector2(c.x * 32 + 16, c.y * 32 + 4))
			await get_tree().create_timer(0.6).timeout
			get_viewport().get_texture().get_image().save_png(out + "/%02d_%s.png" % [n, id])
			n += 1
	World.wait_until(true)
	game._load_room("z1_puits", Vector2(15 * 32, 24 * 32))
	game._spawn_timer = 0.0
	await get_tree().create_timer(2.5).timeout
	get_viewport().get_texture().get_image().save_png(out + "/%02d_nuit.png" % n)
	get_tree().quit()
