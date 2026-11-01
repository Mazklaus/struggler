class_name Herse
extends StaticBody2D
## La herse du sentier des pendus : on tire la chaîne (haut, à côté), la herse remonte et
## retombe presque aussitôt. Il faut la Ruée pour passer dessous à temps.

@export var open_time := 0.9

var gate := Rect2()          # le passage fermé par la herse
var chain := Rect2()         # la chaîne à tirer
var flag := ""               # une fois le boss vaincu, la herse reste levée
var _open := 0.0             # 0 fermée, 1 levée
var _timer := 0.0
var _shape: CollisionShape2D


func _ready() -> void:
	z_index = 5
	_shape = CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = gate.size
	_shape.shape = box
	_shape.position = gate.get_center()
	add_child(_shape)


func pull() -> void:
	if _timer > 0.0:
		return
	_timer = open_time
	Sfx.play("mur", -6.0, 1.4)


func near_chain(r: Rect2) -> bool:
	return chain.grow(20).intersects(r)


func is_open() -> bool:
	return _open > 0.95


func _physics_process(delta: float) -> void:
	var stay := flag != "" and World.flags.has(flag)
	if _timer > 0.0:
		_timer -= delta
		_open = minf(_open + delta * 14.0, 1.0)
	elif stay:
		_open = 1.0
	else:
		# Elle retombe d'un coup ; si Wendel est dessous, elle le repousse.
		var was := _open
		_open = maxf(_open - delta * 10.0, 0.0)
		if was > 0.0 and _open == 0.0:
			Sfx.play("coup_lourd", -4.0, 0.7)
			Game.inst.shake(5.0)
	_shape.set_deferred("disabled", _open > 0.6)
	queue_redraw()


func _draw() -> void:
	var lift := gate.size.y * _open
	var g := Rect2(gate.position - Vector2(0, lift), gate.size)
	var col := Color(0.3, 0.3, 0.32)
	var x := g.position.x + 4.0
	while x < g.end.x:
		draw_line(Vector2(x, g.position.y), Vector2(x, g.end.y + 6.0), col, 4.0)
		x += 10.0
	for k in 3:
		var y := g.position.y + 8.0 + k * g.size.y / 3.0
		draw_line(Vector2(g.position.x, y), Vector2(g.end.x, y), col, 3.0)
	# la chaîne
	var c := chain.get_center()
	for k in 6:
		draw_arc(c + Vector2(0, -40 + k * 9), 4.0, 0.0, TAU, 8, Color(0.55, 0.55, 0.58), 2.0)
	draw_rect(Rect2(c + Vector2(-5, 14), Vector2(10, 8)), Color(0.4, 0.4, 0.42))
