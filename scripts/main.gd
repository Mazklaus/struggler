class_name Game
extends Node2D
## Le jeu : écran titre, salles reliées entre elles, repos aux cercles de sel et aux brasiers,
## cycle jour/nuit de la marque, mort et ombre de marqué, textes (lettres, objets).

static var inst: Game
## Si ce n'est pas vide, on saute l'écran titre et on démarre dans cette salle (tests).
static var debug_room := ""

enum M { TITLE, PLAY, REST, TEXT, FADE }

const TILE := 32.0
const NIGHT_TINT := Color(0.5, 0.56, 0.8)
const SPIRITS_PER_ROOM := 3
const TRIAL_LENGTH := 45.0
## Ce que murmurent les esprits pendant l'épreuve de Corvin.
const VOICES := ["Wendel...", "Pourquoi tu es parti ?", "Il fait froid, ici.", "Tu avais promis de revenir.",
	"Ouvre le cercle.", "Je t'ai attendu.", "Gerold t'appelle."]

var mode := M.TITLE
var stage: Node2D
var room: Room
var player: Player
var fx: Fx
var camera: Camera2D
var hud: Hud
var tint: CanvasModulate
var water_rects: Array[Rect2] = []
var hazard_rects: Array[Rect2] = []

# Écran titre et menus (lus par l'interface)
var title_items: Array = []
var title_index := 0
var menu_items: Array = []
var menu_index := 0
var text_title := ""
var text_body := ""
var fade := 0.0
var banner := ""
var banner_time := 0.0
var boss                    # boss engagé dans la salle (barre de vie en bas de l'écran)
var doors_locked := false   # pendant un combat de boss, on ne sort pas
var mercy := false          # pendant une scène, Wendel ne peut pas mourir
var trial_time := 0.0       # l'épreuve de Corvin : temps restant avant l'aube (0 = pas d'épreuve)
var event_time := -1.0      # la première nuit dans la Lande : temps depuis le début de la scène
var _knight: Node2D

var _input_frame := 0
var _text_since := 0.0
var _door_cd := 0.0
var _spawn_timer := 3.0
var _hitstop_end := 0
var _shake := 0.0


func _enter_tree() -> void:
	inst = self


func _ready() -> void:
	InputSetup.setup()
	process_mode = Node.PROCESS_MODE_ALWAYS

	tint = CanvasModulate.new()
	add_child(tint)
	stage = Node2D.new()
	stage.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(stage)

	fx = Fx.new()
	fx.z_index = 20
	stage.add_child(fx)

	camera = Camera2D.new()
	camera.zoom = Vector2(1.15, 1.15)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	stage.add_child(camera)

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE

	World.night_changed.connect(_on_night_changed)

	if debug_room != "":
		World.debug_all()
		_begin(debug_room, Vector2.INF)
	else:
		World.cycle_running = false
		title_items = []
		if World.has_save():
			title_items.append(["continuer", "Continuer"])
		title_items.append(["nouvelle", "Nouvelle partie"])
		title_items.append(["essai", "Salle d'essai (toutes les armes)"])
		mode = M.TITLE


# =============================================================================
#  Démarrer, entrer dans une salle
# =============================================================================

func _begin(room_id: String, pos: Vector2) -> void:
	player = Player.new()
	player.max_hp = World.max_hp
	player.weapon = World.weapon
	stage.add_child(player)
	_load_room(room_id, pos)
	if World.rest_room == "":
		World.rest_room = room.id
		World.rest_pos = player.position
	player.spawn_point = player.position
	mode = M.PLAY
	get_tree().paused = false


func new_game() -> void:
	World.new_game()
	_begin(Rooms.START_ROOM, Vector2.INF)
	World.save_game()
	show_text("Hautfer, le lendemain",
		"Wendel se réveille sous les décombres de la mine.\nAutour de lui, des centaines de corps : tout le bourg.\n\nAu cou, une marque qui saigne.\nDe la masse d'armes de Doldrey, il ne reste qu'un tronçon.")


func continue_game() -> void:
	if not World.load_game():
		new_game()
		return
	_begin(World.rest_room, World.rest_pos)


func _load_room(room_id: String, pos: Vector2) -> void:
	if is_instance_valid(room):
		stage.remove_child(room)
		room.queue_free()
	room = Room.new()
	room.build(room_id)
	stage.add_child(room)
	stage.move_child(room, 0)
	World.current_room = room_id
	boss = null
	doors_locked = false
	trial_time = 0.0
	event_time = -1.0
	mercy = false
	water_rects = room.water
	hazard_rects = room.hazards
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(room.size.x)
	camera.limit_bottom = int(room.size.y)

	if pos == Vector2.INF:
		pos = room.start_pos
	player.position = pos
	player.reset_safe_pos()
	_update_camera()
	camera.reset_smoothing()
	_door_cd = 0.4
	_spawn_timer = randf_range(2.0, 4.0)

	var name_shown: String = room.data.get("name", room_id)
	if name_shown != banner or banner_time <= 0.0:
		banner = name_shown
		banner_time = 2.5

	if not World.shadow.is_empty() and World.shadow.get("room", "") == room_id:
		var sh := MarkedShadow.new()
		sh.amount = int(World.shadow.amount)
		sh.position = Vector2(float(World.shadow.x), float(World.shadow.y))
		room.add_child(sh)


func _go_through(digit: String) -> void:
	var dest: Array = room.data.doors.get(digit, [])
	if dest.is_empty():
		return
	var vel := player.velocity
	await _fade_out()
	_load_room(dest[0], Vector2.ZERO)
	player.position = room.door_arrival(dest[1])
	var r: Rect2 = room.doors.get(dest[1], Rect2())
	if r.end.y >= room.size.y - 1.0:
		vel.y = minf(vel.y, -900.0)   # on remonte par un trou dans le sol
	player.velocity = vel
	player.reset_safe_pos()
	_update_camera()
	camera.reset_smoothing()
	await _fade_in()


func _fade_out() -> void:
	mode = M.FADE
	get_tree().paused = true
	var tw := create_tween()
	tw.tween_property(self, "fade", 1.0, 0.16)
	await tw.finished


func _fade_in() -> void:
	var tw := create_tween()
	tw.tween_property(self, "fade", 0.0, 0.2)
	await tw.finished
	mode = M.PLAY
	get_tree().paused = false


# =============================================================================
#  Mort et repos
# =============================================================================

## Appelé par Wendel à la fin de sa chute. La ferraille reste là où il est tombé, gardée par
## son ombre ; s'il mourait avant de la reprendre, l'ancienne ombre est perdue.
func player_died() -> void:
	World.shadow = {}
	if World.scrap > 0:
		var at := player.safe_position()
		World.shadow = {"room": room.id, "x": at.x, "y": at.y, "amount": World.scrap}
		World.scrap = 0
	World.save_game()
	await _fade_out()
	_load_room(World.rest_room, World.rest_pos)
	player.revive()
	await _fade_in()


## Wendel s'assoit au cercle de sel ou au brasier : vie rendue, partie sauvegardée.
func open_rest(kind: String) -> void:
	player.hp = player.max_hp
	World.rest_room = room.id
	World.rest_pos = player.position
	World.weapon = player.weapon
	World.save_game()
	Sfx.play("panse", -2.0, 0.9)
	fx.text(player.position + Vector2(0, -70), "Partie sauvegardée", Color(0.95, 0.92, 0.85), 16)
	_build_rest_menu(kind)
	menu_index = 0
	mode = M.REST
	_input_frame = Engine.get_process_frames()
	get_tree().paused = true


func _build_rest_menu(kind: String) -> void:
	menu_items = []
	if room.data.get("epreuve", false) and World.flags.get("corvin", 0) == 2 and not World.flags.has("epreuve"):
		menu_items.append(["epreuve", "Tenir la nuit (l'épreuve de Corvin)"])
	if World.weapons.size() > 1:
		menu_items.append(["arme", "Changer d'arme : %s" % player.weapon_name(player.next_weapon())])
	if World.is_night():
		menu_items.append(["jour", "Attendre l'aube"])
	else:
		menu_items.append(["nuit", "Attendre la nuit"])
	menu_items.append(["partir", "Se relever"])
	menu_items.append([kind, ""])   # mémorise le type de repos (non affiché)


func _rest_choice(id: String) -> void:
	match id:
		"arme":
			player.switch_weapon()
			World.weapon = player.weapon
			_build_rest_menu(menu_items[-1][0])
		"epreuve":
			await _fade_out()
			World.wait_until(true)
			trial_time = TRIAL_LENGTH
			doors_locked = true
			_spawn_timer = 1.0
			await get_tree().create_timer(0.3, true).timeout
			await _fade_in()
			banner = "Tiens jusqu'à l'aube, sans sortir du cercle"
			banner_time = 3.0
		"nuit", "jour":
			await _fade_out()
			World.wait_until(id == "nuit")
			await get_tree().create_timer(0.3, true).timeout
			await _fade_in()
		_:
			mode = M.PLAY
			get_tree().paused = false


## Un boss s'éveille : son nom s'affiche et la salle se ferme.
func start_boss(b) -> void:
	boss = b
	doors_locked = true
	banner = b.NAME
	banner_time = 3.0


func boss_defeated(b) -> void:
	boss = null
	doors_locked = false
	World.flags["boss:" + b.ID] = true
	World.scrap += 60
	fx.text(b.position + Vector2(0, -60), "+60 ferraille", Color(0.85, 0.8, 0.7), 18)
	World.save_game()
	if b is SeigneurGibets:
		show_text("Le Seigneur des gibets",
			"Il tombe à genoux sous son arbre. La corde à son cou se tend une dernière fois.\n\n« J'ai pendu pour l'armée. Puis pour moi. Puis pour lui.\nIl m'avait promis que l'arbre se tairait. »\n\nLes pendus du Grand Gibet se balancent, sans un bruit.\nPlus haut, la route de Koka longe la crête, au-dessus des ruines de Hautfer.")
	if b is Contremaitre:
		show_text("Le Contremaître",
			"La masse se défait. Wendel reconnaît des visages.\n\nLe vieux Hendrik, qui lui avait appris à tenir une pioche.\nGrete la boulangère, et ses deux fils.\nAldo, le contremaître, qui criait la cadence au fond des puits.\n\nIl les cherche tous, un par un.\nIlse n'est pas parmi eux.")


## Parler à un personnage (haut, à côté de lui).
func talk(id: String) -> void:
	var t: Array = Dialogues.talk(id)
	if t[0] == "":
		return
	World.save_game()
	Sfx.play("panse", -6.0, 1.1)
	show_text(t[0], t[1])


func show_text(title: String, body: String) -> void:
	text_title = title
	text_body = body
	mode = M.TEXT
	_text_since = 0.0
	_input_frame = Engine.get_process_frames()
	get_tree().paused = true


func _on_night_changed(night: bool) -> void:
	if is_instance_valid(room):
		room.set_night(night)
		room.deco.queue_redraw()
	if is_instance_valid(player) and mode == M.PLAY:
		banner = "La nuit tombe : la marque saigne" if night else "L'aube"
		banner_time = 2.5
		Sfx.play("glas", -10.0, 0.7 if night else 1.2)


# =============================================================================
#  Boucle
# =============================================================================

func _process(delta: float) -> void:
	if _hitstop_end > 0 and Time.get_ticks_msec() >= _hitstop_end:
		_hitstop_end = 0
		Engine.time_scale = 1.0
	banner_time = maxf(banner_time - delta, 0.0)
	tint.color = Color.WHITE.lerp(NIGHT_TINT, World.night_amount()) if mode != M.TITLE else Color.WHITE

	if Input.is_action_just_pressed("aide"):
		hud.show_help = not hud.show_help

	match mode:
		M.TITLE:
			_title_input()
		M.REST:
			_menu_input()
		M.TEXT:
			_text_since += delta
			if _text_since > 0.25 and _input_frame != Engine.get_process_frames() and _confirm_pressed():
				mode = M.PLAY
				get_tree().paused = false
		M.PLAY:
			_play(delta)


func _play(delta: float) -> void:
	_update_camera()
	_shake = maxf(_shake - delta * 40.0, 0.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	if Input.is_action_just_pressed("recommencer"):
		Engine.time_scale = 1.0
		get_tree().paused = false
		get_tree().reload_current_scene()
		return

	_door_cd = maxf(_door_cd - delta, 0.0)
	if _door_cd <= 0.0 and not player.is_dead() and not doors_locked:
		var body := player.get_hurt_rect()
		for digit in room.doors:
			if body.intersects(room.doors[digit]):
				_go_through(digit)
				return

	_update_trial(delta)
	_update_event(delta)

	# La nuit, les esprits viennent à la marque.
	if World.is_night() and not room.spirit_points.is_empty() and event_time < 0.0:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = randf_range(1.0, 2.0) if trial_time > 0.0 else randf_range(4.0, 7.0)
			var count := 0
			for n in room.get_children():
				if n is Spirit and not n.daylight:
					count += 1
			var most: int = 7 if trial_time > 0.0 else room.data.get("spirits", SPIRITS_PER_ROOM)
			if count < most:
				_spawn_spirit()


## L'épreuve de Corvin : une nuit entière dans le cercle des tranchées.
func _update_trial(delta: float) -> void:
	if trial_time <= 0.0:
		return
	if player.is_dead():
		trial_time = 0.0
		doors_locked = false
		return
	if not room.in_salt(player.position):
		trial_time = 0.0
		doors_locked = false
		banner = "Tu es sorti du cercle. Corvin le saura."
		banner_time = 3.0
		return
	trial_time -= delta
	if randf() < delta * 0.5:
		var at := player.position + Vector2(randf_range(-260, 260), randf_range(-160, -60))
		fx.text(at, VOICES.pick_random(), Color(0.6, 0.95, 0.9, 0.8), 14)
	if trial_time <= 0.0:
		trial_time = 0.0
		doors_locked = false
		World.flags["epreuve"] = true
		World.wait_until(false)
		World.save_game()
		banner = "L'aube. Tu as tenu."
		banner_time = 3.0


## La première nuit dans la Lande : elle tombe d'un coup, les spectres submergent Wendel,
## et un homme en armure noire surgit.
func _update_event(delta: float) -> void:
	var ev: String = room.data.get("event", "")
	if ev != "premiere_nuit" or World.flags.has("premiere_nuit"):
		return
	if event_time < 0.0:
		if player.position.x < room.data.get("event_x", 0) * TILE:
			return
		event_time = 0.0
		mercy = true
		World.wait_until(true)
		banner = "La nuit tombe d'un coup"
		banner_time = 3.0
		for i in 8:
			var s := Spirit.new()
			s.position = player.position + Vector2(randf_range(-420, 420), randf_range(-300, -120))
			room.add_child(s)
		return
	event_time += delta
	if not is_instance_valid(_knight) and event_time > 6.0 and not World.flags.has("chevalier_vu"):
		World.flags["chevalier_vu"] = true
		_knight = ChevalierNoir.new()
		_knight.position = Vector2(maxf(player.position.x - 560.0, 80.0), player.position.y)
		room.add_child(_knight)
	if World.flags.has("chevalier_vu") and not is_instance_valid(_knight):
		event_time = -1.0
		mercy = false
		World.flags["premiere_nuit"] = true
		World.save_game()
		show_text("La première nuit",
			"Un homme en armure noire. Une lame qu'aucun homme ne devrait pouvoir porter.\nIl a taillé les spectres comme on fauche, sans un regard pour toi.\n\nPuis il est reparti vers l'est, dans le noir, sans un mot.\n\nAu loin, une tour blanche, cerclée de sel. Une lumière brûle en haut.")


func _spawn_spirit() -> void:
	var pts := room.spirit_points.filter(func(v): return v.distance_to(player.position) > 260.0)
	if pts.is_empty():
		return
	var s := Spirit.new()
	s.position = pts.pick_random()
	room.add_child(s)
	fx.sparks(s.position, 12, LevelDraw.C_SPIRIT, 120.0, -150.0, 0.8)


func _update_camera() -> void:
	if is_instance_valid(player):
		camera.position = player.position + Vector2(player.facing * 60.0, -40.0)


func _confirm_pressed() -> bool:
	return Input.is_action_just_pressed("saut") or Input.is_action_just_pressed("attaque") \
		or Input.is_action_just_pressed("haut") or Input.is_action_just_pressed("panser")


func _nav() -> int:
	if Input.is_action_just_pressed("bas"):
		return 1
	if Input.is_action_just_pressed("haut"):
		return -1
	return 0


func _title_input() -> void:
	title_index = wrapi(title_index + _nav(), 0, title_items.size())
	if Input.is_action_just_pressed("saut") or Input.is_action_just_pressed("attaque"):
		match title_items[title_index][0]:
			"continuer":
				continue_game()
			"nouvelle":
				new_game()
			"essai":
				World.debug_all()
				_begin(Rooms.TEST_ROOM, Vector2.INF)


func _menu_input() -> void:
	if _input_frame == Engine.get_process_frames():
		return
	var shown := menu_items.size() - 1
	menu_index = wrapi(menu_index + _nav(), 0, shown)
	if Input.is_action_just_pressed("saut") or Input.is_action_just_pressed("attaque"):
		_rest_choice(menu_items[menu_index][0])
	elif Input.is_action_just_pressed("panser") or Input.is_action_just_pressed("ruee"):
		_rest_choice("partir")


# =============================================================================
#  Effets communs
# =============================================================================

## Arrêt sur image : chaque coup se sent.
func hitstop(seconds: float) -> void:
	Engine.time_scale = 0.05
	_hitstop_end = maxi(_hitstop_end, Time.get_ticks_msec() + int(seconds * 1000.0))


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func add_blood(pos: Vector2) -> void:
	var pool := BloodPool.new()
	pool.position = pos
	room.add_child(pool)
	room.move_child(pool, 1)


func floor_below(pos: Vector2) -> float:
	return room.floor_below(pos)
