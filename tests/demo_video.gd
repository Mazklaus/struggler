extends Node
## Séquence de jeu jouée automatiquement, pour enregistrer une vidéo de démonstration
## (outil de DA, non lancé par les tests) :
## xvfb-run godot --rendering-driver opengl3 --write-movie demo.avi --fixed-fps 30 \
##     --resolution 1920x1080 res://tests/demo_video.tscn
## Un petit « pilote » tient la droite, frappe les ennemis proches, saute les murs, et place
## un coup vers le haut et un coup plongeant pour montrer les animations.

const DUREE := 32.0
const PUITS_T := 22.0   # au-delà (ou au bout du carreau), on passe au Grand Puits
var _puits := false
var _combat := 0.0
var game: Game
var t := 0.0
var _held := {}
var _next_hit := 0.0
var _script_done := {}


func _ready() -> void:
	Game.debug_room = ""
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.new_game()
	await get_tree().create_timer(0.3).timeout
	game.mode = Game.M.PLAY
	get_tree().paused = false
	game._load_room("h21_carreau", Vector2(4 * 32, 18 * 32))
	game.hud.show_help = false   # cache l'aide à l'écran


func _hold(a: String, on: bool) -> void:
	if on and not _held.get(a, false):
		Input.action_press(a)
	elif not on and _held.get(a, false):
		Input.action_release(a)
	_held[a] = on


func _tap(a: String) -> void:
	Input.action_press(a)
	await get_tree().create_timer(0.05).timeout
	Input.action_release(a)


func _once(key: String) -> bool:
	if _script_done.has(key):
		return false
	_script_done[key] = true
	return true


func _physics_process(delta: float) -> void:
	if game == null or not is_instance_valid(game.player):
		return
	t += delta
	if t > DUREE:
		get_tree().quit()
		return
	var p: Player = game.player
	game.hud.show_help = false
	p.hp = p.max_hp   # la démo ne doit pas mourir
	if not _puits and (t > PUITS_T or p.global_position.x > 94 * 32):
		_puits = true
		for a in _held.keys():
			_hold(a, false)
		game._load_room("h23_grand_puits", Vector2(20 * 32, 3 * 32))
		return
	if _puits:
		# Chute dans le puits : on se laisse tomber en zigzaguant pour longer les corniches.
		var droite := fmod(t, 3.0) < 1.5
		_hold("droite", droite)
		_hold("gauche", not droite)
		return
	# Petite mise en scène : un coup vers le haut, puis un saut avec coup plongeant.
	if t > 3.0 and t < 3.6:
		_hold("droite", false)
		_hold("haut", true)
		if _once("haut"):
			_tap("attaque")
		return
	_hold("haut", false)
	if t > 4.2 and t < 5.2:
		if _once("saut1"):
			_tap("saut")
		if t > 4.6:
			_hold("bas", true)
			if _once("plonge"):
				_tap("attaque")
		return
	_hold("bas", false)
	# Ennemi proche devant : on s'arrête et on frappe en rythme.
	var target: Node2D = null
	for e in get_tree().get_nodes_in_group("hittable"):
		var vivant: bool = (e is Enemy and not e.dead) or (e is Soldier and e.hp > 0)
		if vivant and absf(e.global_position.y - p.global_position.y) < 80.0:
			var dx: float = e.global_position.x - p.global_position.x
			if dx > -20.0 and dx < 110.0:
				target = e
	if target and _combat > 4.0:
		# Combat trop long (bouclier) : on saute par-dessus et on continue.
		_hold("droite", true)
		if p.is_on_floor():
			_tap("saut")
		return
	if target:
		_combat += delta
		_hold("droite", false)
		if t >= _next_hit:
			_next_hit = t + 0.32
			_tap("attaque")
		return
	_combat = 0.0
	_hold("droite", true)
	if p.is_on_wall() and p.is_on_floor():
		_tap("saut")
