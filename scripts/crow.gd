class_name Crow
extends Enemy
## Corbeau de la Lande : perché, il guette ; quand Wendel passe, il plonge sur lui,
## puis remonte se percher. Un coup suffit.

enum S { PERCH, DIVE, RISE }

var state := S.PERCH
var _home := Vector2.ZERO
var _t := 0.0
var _dir := Vector2.ZERO


func _ready() -> void:
	max_hp = 1
	scrap_drop = 1
	body_size = Vector2(26, 18)
	super._ready()
	collision_layer = 0
	collision_mask = 0
	_home = position


func _physics_process(delta: float) -> void:
	_t += delta
	_tick_status(delta)
	if dead:
		return
	var p := Game.inst.player
	match state:
		S.PERCH:
			position = position.move_toward(_home, 160.0 * delta)
			var d := p.position.distance_to(position)
			if _t > 1.2 and d < 260.0 and not p.is_dead():
				_dir = ((p.position + Vector2(0, -20)) - position).normalized()
				facing = 1 if _dir.x > 0.0 else -1
				state = S.DIVE
				_t = 0.0
				Sfx.play("souffle", -12.0, 1.8)
		S.DIVE:
			position += _dir * 430.0 * delta
			_touch_player()
			if _t > 0.7:
				state = S.RISE
				_t = 0.0
		S.RISE:
			position += Vector2(facing * 120.0, -260.0) * delta
			if _t > 0.6:
				state = S.PERCH
				_t = 0.0
	queue_redraw()


func take_hit(info: Dictionary) -> String:
	if not _apply_hit(info):
		return "none"
	return "hit"


func _on_death() -> void:
	Game.inst.fx.sparks(position, 10, Color(0.15, 0.15, 0.17), 220.0, 900.0, 0.6)
	queue_free()


func _draw() -> void:
	var c := _body_color(Color(0.12, 0.12, 0.14))
	var flap := sin(_t * (6.0 if state == S.PERCH else 22.0)) * (3.0 if state == S.PERCH else 10.0)
	draw_circle(Vector2.ZERO, 9.0, c)
	draw_colored_polygon(PackedVector2Array([Vector2(-4, -2), Vector2(-20, -6 - flap), Vector2(-6, 4)]), c)
	draw_colored_polygon(PackedVector2Array([Vector2(4, -2), Vector2(20, -6 - flap), Vector2(6, 4)]), c)
	draw_colored_polygon(PackedVector2Array([Vector2(facing * 8, -3), Vector2(facing * 16, 0), Vector2(facing * 8, 2)]), Color(0.5, 0.45, 0.3))
