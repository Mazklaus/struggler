class_name Dummy
extends Node2D
## Mannequin d'entraînement : encaisse tout, pour travailler la Cadence.

const SIZE := Vector2(30, 64)

var _wobble := 0.0
var _flash := 0.0
var _total := 0
var _wounds := 0
var _wound_timer := 0.0
var _bleed := 0.0
var _bleed_tick := 0.0


func _ready() -> void:
	add_to_group("hittable")
	z_index = 3


func get_hurt_rect() -> Rect2:
	return Rect2(position - SIZE * 0.5, SIZE)


func take_hit(info: Dictionary) -> String:
	_wobble = 1.0 * signf(info.dir.x if info.dir.x != 0.0 else 1.0)
	_flash = 0.08
	_total += info.damage
	Game.inst.fx.text(position + Vector2(randf_range(-10, 10), -48), str(info.damage), Color(1, 1, 1), 16)
	if info.get("entaille", false):
		_wounds += 1
		_wound_timer = 3.0
		if _wounds >= 5:
			_wounds = 0
			_bleed = 1.5
			Game.inst.fx.text(position + Vector2(0, -66), "Saignée !", Color(0.9, 0.2, 0.2), 18)
			Game.inst.fx.sparks(position, 20, Color(0.6, 0.05, 0.05), 300.0, 1200.0, 0.8)
	return "hit"


func is_bleeding() -> bool:
	return _bleed > 0.0


func _process(delta: float) -> void:
	_wobble = move_toward(_wobble, 0.0, delta * 3.0)
	_flash = maxf(_flash - delta, 0.0)
	_wound_timer = maxf(_wound_timer - delta, 0.0)
	if _wound_timer <= 0.0:
		_wounds = 0
	if _bleed > 0.0:
		_bleed -= delta
		_bleed_tick -= delta
		if _bleed_tick <= 0.0:
			_bleed_tick = 0.25
			_total += 1
			Game.inst.fx.text(position + Vector2(randf_range(-10, 10), -40), "1", Color(0.9, 0.3, 0.3), 14)
	queue_redraw()


func _draw() -> void:
	var tilt := sin(_wobble * 12.0) * _wobble * 0.25
	draw_set_transform(Vector2(0, SIZE.y * 0.5), tilt, Vector2.ONE)
	var col := Color(1, 1, 1) if _flash > 0.0 else Color(0.62, 0.55, 0.42)
	draw_rect(Rect2(-3, -SIZE.y, 6, SIZE.y), Color(0.4, 0.32, 0.22))
	draw_rect(Rect2(-SIZE.x * 0.5, -SIZE.y + 4, SIZE.x, SIZE.y * 0.6), col)
	draw_circle(Vector2(0, -SIZE.y - 2), 10.0, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in _wounds:
		draw_line(Vector2(-12 + i * 6, -SIZE.y * 0.5 - 18), Vector2(-9 + i * 6, -SIZE.y * 0.5 - 24), Color(0.85, 0.15, 0.15), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-30, SIZE.y * 0.5 + 16), "total %d" % _total, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.78, 0.7, 0.6))
