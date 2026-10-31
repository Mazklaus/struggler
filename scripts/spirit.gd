class_name Spirit
extends Enemy
## Esprit de la marque : attiré par le sang de Wendel la nuit, il traverse les murs.
## Il s'approche en flottant, se gonfle de lumière (signal), puis fond sur Wendel.
## Il n'entre jamais dans un cercle de sel, et se dissout à l'aube.

enum S { DRIFT, GLOW, DART, RETREAT, FADE }

@export var drift_speed := 85.0
@export var glow_time := 0.55
@export var dart_speed := 470.0

var daylight := false   # esprit qui rôde même le jour (galeries de Hautfer)
var state := S.DRIFT
var _t := 0.0
var _cd := 1.0
var _dir := Vector2.ZERO
var _seed := 0.0
var _push := Vector2.ZERO


func _ready() -> void:
	max_hp = 3
	scrap_drop = 1
	body_size = Vector2(30, 34)
	super._ready()
	collision_layer = 0
	collision_mask = 0
	_seed = randf() * TAU
	z_index = 6


func _physics_process(delta: float) -> void:
	_t += delta
	_cd = maxf(_cd - delta, 0.0)
	_tick_status(delta)
	if dead:
		return
	if state != S.FADE and not daylight and not World.is_night():
		_go(S.FADE)

	var p := Game.inst.player
	var target := p.position + Vector2(0, -20)
	var safe: bool = Game.inst.room.in_salt(p.position) or p.is_dead()
	if safe:
		# Le sel les tient à distance : ils tournent autour en attendant.
		var away := (position - p.position)
		if away.length() < 1.0:
			away = Vector2.UP
		target = p.position + away.normalized() * 190.0 + Vector2(0, -60)
	var to_t := target - position
	_push = _push.move_toward(Vector2.ZERO, 900.0 * delta)

	match state:
		S.DRIFT:
			var wob := Vector2(sin(_t * 2.3 + _seed), cos(_t * 1.7 + _seed)) * 30.0
			velocity = to_t.normalized() * drift_speed + wob
			if not safe and to_t.length() < 170.0 and _cd <= 0.0:
				_go(S.GLOW)
		S.GLOW:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			if _t >= glow_time:
				_dir = (p.position + Vector2(0, -10) - position).normalized()
				_go(S.DART)
				Sfx.play("souffle", -6.0, 0.6)
		S.DART:
			velocity = _dir * dart_speed
			if _t >= 0.42 or Game.inst.room.in_salt(position):
				_go(S.RETREAT)
		S.RETREAT:
			velocity = velocity.move_toward(-_dir * 90.0, 900.0 * delta)
			if _t >= 0.7:
				_cd = randf_range(1.2, 2.4)
				_go(S.DRIFT)
		S.FADE:
			velocity = Vector2(0, -40)
			if _t >= 1.0:
				queue_free()
	position += (velocity + _push) * delta
	if state in [S.DRIFT, S.GLOW, S.DART] and not Game.inst.room.in_salt(position):
		_touch_player()
	queue_redraw()


func take_hit(info: Dictionary) -> String:
	if state == S.FADE or not _apply_hit(info):
		return "none"
	if not dead:
		_push = Vector2(info.dir.x, -0.4).normalized() * 380.0
		if state == S.GLOW:
			_go(S.RETREAT)
	return "hit"


func _go(s: S) -> void:
	state = s
	_t = 0.0


func _on_death() -> void:
	Game.inst.fx.sparks(position, 22, LevelDraw.C_SPIRIT, 260.0, -200.0, 0.9)
	queue_free()


func _draw() -> void:
	var c := LevelDraw.C_SPIRIT
	var a := 0.75
	if state == S.FADE:
		a *= 1.0 - _t
	if state == S.GLOW:
		a = 0.5 + 0.5 * sin(_t * 40.0)
		draw_circle(Vector2.ZERO, 26.0 + 14.0 * (_t / glow_time), Color(c.r, c.g, c.b, 0.2))
	if _flash > 0.0:
		c = Color(1, 1, 1)
	# Une traîne qui suit le mouvement, puis un visage.
	var back := -velocity.normalized() if velocity.length() > 10.0 else Vector2.DOWN
	var side := Vector2(-back.y, back.x)
	var tail := back * 30.0 + side * sin(_t * 8.0) * 5.0
	draw_colored_polygon(PackedVector2Array([side * 11.0, tail, -side * 11.0]), Color(c.r, c.g, c.b, a * 0.5))
	draw_circle(Vector2(0, -2), 14.0, Color(c.r, c.g, c.b, a * 0.8))
	draw_circle(Vector2(-5, -6), 3.0, Color(0.05, 0.1, 0.1, a))
	draw_circle(Vector2(5, -6), 3.0, Color(0.05, 0.1, 0.1, a))
	draw_line(Vector2(-4, 3), Vector2(4, 3), Color(0.05, 0.1, 0.1, a), 2.0)
	_draw_wounds(-22.0)
