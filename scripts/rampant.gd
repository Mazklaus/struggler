class_name Rampant
extends Enemy
## Mineur rampant : un des corps de Hautfer que le sacrifice n'a pas laissé mourir.
## Il rampe vers Wendel, se redresse (signal) puis se jette en avant au ras du sol.

enum S { CRAWL, REAR, LUNGE, RECOVER, STAGGER }

@export var crawl_speed := 55.0
@export var rear_time := 0.45
@export var lunge_speed := 420.0

const GRAVITY := 1900.0

var state := S.CRAWL
var _t := 0.0
var _cd := 0.8


func _ready() -> void:
	max_hp = 7
	scrap_drop = 4
	body_size = Vector2(44, 24)
	super._ready()
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = body_size
	shape.shape = box
	add_child(shape)
	facing = -1 if randf() < 0.5 else 1


func _physics_process(delta: float) -> void:
	_t += delta
	_cd = maxf(_cd - delta, 0.0)
	_tick_status(delta)
	if dead:
		return
	velocity.y = minf(velocity.y + GRAVITY * delta, 900.0)
	var p := Game.inst.player
	var to_p := p.position - position
	var sees := absf(to_p.x) < 380.0 and absf(to_p.y) < 90.0 and not p.is_dead()

	match state:
		S.CRAWL:
			if sees:
				facing = 1 if to_p.x > 0.0 else -1
			elif is_on_wall() or not _ground_ahead():
				facing = -facing
			var speed := crawl_speed * (1.6 if sees else 1.0)
			velocity.x = facing * speed if _ground_ahead() else 0.0
			if sees and absf(to_p.x) < 170.0 and _cd <= 0.0:
				_go(S.REAR)
		S.REAR:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			if _t >= rear_time:
				velocity.x = facing * lunge_speed
				velocity.y = -160.0
				_go(S.LUNGE)
		S.LUNGE:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			if _t >= 0.45 and is_on_floor():
				_go(S.RECOVER)
		S.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
			if _t >= 0.7:
				_cd = randf_range(0.8, 1.6)
				_go(S.CRAWL)
		S.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			if _t >= 0.3:
				_cd = maxf(_cd, 0.4)
				_go(S.CRAWL)
	move_and_slide()
	_touch_player()
	queue_redraw()


func _ground_ahead() -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = global_position + Vector2(facing * (body_size.x * 0.5 + 6.0), body_size.y * 0.5 + 8.0)
	q.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()


func take_hit(info: Dictionary) -> String:
	if not _apply_hit(info):
		return "none"
	if dead:
		return "hit"
	# Le bond lancé ne s'interrompt pas avec un coup léger.
	if state != S.LUNGE or info.heavy:
		_go(S.STAGGER)
		velocity.x = info.dir.x * (300.0 if info.heavy else 170.0)
	return "hit"


func _go(s: S) -> void:
	state = s
	_t = 0.0


func _on_death() -> void:
	Game.inst.fx.sparks(position, 26, Color(0.6, 0.05, 0.05), 340.0, 1200.0, 0.8)
	Game.inst.add_blood(position + Vector2(0, body_size.y * 0.5))
	queue_free()


func _draw() -> void:
	var col := _body_color(Color(0.5, 0.44, 0.4))
	var h := body_size.y
	if state == S.REAR:
		h = body_size.y + 18.0 * minf(_t / rear_time, 1.0)
		if int(_t * 24.0) % 2 == 0:
			draw_rect(Rect2(-body_size.x * 0.5 - 3, body_size.y * 0.5 - h - 3, body_size.x + 6, h + 6), Color(1.0, 0.25, 0.2, 0.9), false, 3.0)
	var r := Rect2(-body_size.x * 0.5, body_size.y * 0.5 - h, body_size.x, h)
	draw_rect(r, col)
	# Tête et bras qui traînent
	draw_circle(Vector2(facing * (body_size.x * 0.5 - 4), r.position.y + 6), 8.0, col.darkened(0.1))
	draw_line(Vector2(facing * 10, 6), Vector2(facing * 30, 12), col.darkened(0.25), 4.0)
	draw_rect(Rect2(facing * (body_size.x * 0.5 - 8) - 3, r.position.y + 3, 6, 4), Color(0.15, 0.1, 0.1))
	_draw_wounds(r.position.y)
	var w := 36.0
	draw_rect(Rect2(-w * 0.5, r.position.y - 10, w, 4), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(-w * 0.5, r.position.y - 10, w * hp / max_hp, 4), Color(0.75, 0.15, 0.15))
