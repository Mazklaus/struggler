extends Node
## Captures d'écran de chaque salle (outil de développement, non lancé par les tests).
## xvfb-run godot --rendering-driver opengl3 res://tests/shots.tscn -- <dossier> [salles...]

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
	# Une capture par écran de chaque salle de Hautfer (ou des salles données après le dossier).
	var ids: Array = OS.get_cmdline_user_args().slice(1)
	if ids.is_empty():
		ids = Rooms.DATA.keys().filter(func(k): return k.begins_with("h"))
	var n := 1
	for id in ids:
		var rows: Array = Rooms.DATA[id].rows
		var w: int = rows[0].length() / 40
		var h: int = rows.size() / 22
		for j in h:
			for i in w:
				game._load_room(id, Vector2((i * 40 + 20) * 32, (j * 22 + 11) * 32))
				game.player.velocity = Vector2.ZERO
				await get_tree().create_timer(0.15).timeout
				get_viewport().get_texture().get_image().save_png(out + "/%02d_%s_%d_%d.png" % [n, id, i, j])
				n += 1
	World.wait_until(true)
	game._load_room("h06_roulage", Vector2(20 * 32, 12 * 32))
	game._spawn_timer = 0.0
	await get_tree().create_timer(2.5).timeout
	get_viewport().get_texture().get_image().save_png(out + "/%02d_nuit.png" % n)
	get_tree().quit()
