class_name Game
extends Node2D
## Monte le niveau de test en blocs, le joueur, les ennemis, la caméra et l'interface.

static var inst: Game

const TILE := 32.0

## Légende : # bloc, X mur fragile (attaque lourde), ^ pics, ~ eau (trempe),
## P départ de Wendel, E soldat, D mannequin d'entraînement.
const LEVEL := [
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
	"#  P       D                                                         XX          E           E                 #",
	"##################~~~~###################################        ##########~~~##################################",
	"#########################################################^^^^^^^^###############################################",
	"################################################################################################################",
	"################################################################################################################",
]

## Panneaux d'aide posés dans le niveau : [colonne, ligne, texte].
const HINTS := [
	[6, 12, "Frappe (J) au son de l'enclume : la Cadence fait chauffer le marteau"],
	[19, 14, "Trempe (E) dans l'eau : refroidit l'arme, bonus de vitesse"],
	[49, 8, "Glissade (C) sous le passage bas"],
	[55, 12, "Ruée (Maj ou L) par-dessus les pics,"],
	[55, 13, "ou frappe vers le bas dessus pour rebondir"],
	[59, 8, "Attaque lourde : maintenir K, relâcher"],
	[73, 7, "Contre (I) juste avant le coup de lance"],
	[73, 8, "Panser (F) : 33 de Rage = 3 PV"],
]

var player: Player
var fx: Fx
var camera: Camera2D
var hud: Hud
var water_rects: Array[Rect2] = []
var hazard_rects: Array[Rect2] = []
var solid_rects: Array[Rect2] = []
var level_size := Vector2.ZERO

var _hitstop_end := 0
var _shake := 0.0


func _enter_tree() -> void:
	inst = self


func _ready() -> void:
	InputSetup.setup()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_level()

	fx = Fx.new()
	fx.z_index = 20
	add_child(fx)

	camera = Camera2D.new()
	camera.zoom = Vector2(1.15, 1.15)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(level_size.x)
	camera.limit_bottom = int(level_size.y)
	add_child(camera)

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_level() -> void:
	var rows: Array = LEVEL
	var w := 0
	for r in rows:
		w = maxi(w, r.length())
	level_size = Vector2(w * TILE, rows.size() * TILE)

	var deco := LevelDraw.new()
	add_child(deco)

	# Blocs pleins : on fusionne les suites horizontales pour limiter les corps physiques.
	var body := StaticBody2D.new()
	add_child(body)
	for y in rows.size():
		var line: String = rows[y]
		var x := 0
		while x < line.length():
			var ch := line[x]
			if ch == "#" or ch == "^":
				var start := x
				while x < line.length() and line[x] == ch:
					x += 1
				var rect := Rect2(start * TILE, y * TILE, (x - start) * TILE, TILE)
				_add_box(body, rect)
				solid_rects.append(rect)
				if ch == "^":
					hazard_rects.append(Rect2(rect.position + Vector2(4, -6), Vector2(rect.size.x - 8, 14)))
				continue
			var cell := Vector2(x * TILE, y * TILE)
			match ch:
				"~":
					water_rects.append(Rect2(cell, Vector2(TILE, TILE)))
				"P":
					player = Player.new()
					player.position = cell + Vector2(TILE * 0.5, TILE - 28.0)
					player.spawn_point = player.position
				"E":
					var e := Soldier.new()
					e.position = cell + Vector2(TILE * 0.5, TILE - 29.0)
					add_child(e)
				"D":
					var d := Dummy.new()
					d.position = cell + Vector2(TILE * 0.5, TILE - 32.0)
					add_child(d)
			x += 1

	# Murs fragiles : un corps par colonne de X, qu'on peut briser.
	var done := {}
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			if line[x] != "X" or done.has(Vector2i(x, y)):
				continue
			var h := 0
			while y + h < rows.size() and x < rows[y + h].length() and rows[y + h][x] == "X":
				done[Vector2i(x, y + h)] = true
				h += 1
			var wall := FragileWall.new()
			wall.rect = Rect2(x * TILE, y * TILE, TILE, h * TILE)
			add_child(wall)

	deco.water = water_rects
	deco.hazards = hazard_rects
	deco.solids = solid_rects
	for hnt in HINTS:
		deco.hints.append([Vector2(hnt[0] * TILE, hnt[1] * TILE), hnt[2]])
	add_child(player)


func _add_box(body: StaticBody2D, rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	body.add_child(shape)


func _process(delta: float) -> void:
	if _hitstop_end > 0 and Time.get_ticks_msec() >= _hitstop_end:
		_hitstop_end = 0
		Engine.time_scale = 1.0
	if is_instance_valid(player):
		camera.position = player.position + Vector2(player.facing * 60.0, -40.0)
	_shake = maxf(_shake - delta * 40.0, 0.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	if Input.is_action_just_pressed("recommencer"):
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
	if Input.is_action_just_pressed("aide"):
		hud.show_help = not hud.show_help


## Arrêt sur image : chaque coup se sent.
func hitstop(seconds: float) -> void:
	Engine.time_scale = 0.05
	_hitstop_end = maxi(_hitstop_end, Time.get_ticks_msec() + int(seconds * 1000.0))


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func add_blood(pos: Vector2) -> void:
	var pool := BloodPool.new()
	pool.position = pos
	add_child(pool)
	move_child(pool, 1)


## Rectangle au sol correspondant à une position (pour poser une flaque).
func floor_below(pos: Vector2) -> float:
	var best := level_size.y
	for r in solid_rects:
		if pos.x >= r.position.x and pos.x <= r.end.x and r.position.y >= pos.y - 4.0:
			best = minf(best, r.position.y)
	return best
