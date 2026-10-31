class_name Contremaitre
extends Enemy
## Le Contremaître : l'amas des mineurs de Hautfer, fondus ensemble par le sacrifice.
## La masse encaisse presque tout ; seuls les visages qui pleurent sont vulnérables.
## Elle frappe à la pioche (onde au sol), lance ses lanternes (flaques de feu), et
## s'effondre en vague de corps qui roule vers Wendel avant de repousser, tous visages ouverts.
## Sous la moitié de sa vie, les visages hurlent : deux s'ouvrent à la fois, et des mineurs
## rampants se détachent de la masse.

enum S { SLEEP, INTRO, WALK, SLAM_WIND, SLAM, SLAM_REC, THROW_WIND, THROW_REC, SHUDDER, COLLAPSE, REFORM, DYING }

const ID := "contremaitre"
const NAME := "Le Contremaître"
const BODY := Vector2(150, 190)
const WAVE := Vector2(210, 46)
const GRAVITY := 1900.0
## Les visages : position par rapport au centre de la masse.
const FACES := [Vector2(-40, 52), Vector2(38, -8), Vector2(-22, -66)]
const FACE_SIZE := Vector2(40, 40)

@export var walk_speed := 42.0
@export var wave_speed := 300.0

var state := S.SLEEP
var phase := 1
var faces_open := [false, false, false]
var _face_timer := 1.0
var _t := 0.0
var _attacks := 0
var _hit_done := false
var _wave_dir := 1


func _ready() -> void:
	max_hp = 70
	scrap_drop = 0
	contact_damage = 1
	body_size = BODY
	super._ready()
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	# Seule la base de la masse heurte le décor : le haut passe à travers les corniches.
	box.size = Vector2(60, 56)
	shape.shape = box
	shape.position.y = BODY.y * 0.5 - 28.0
	add_child(shape)
	z_index = 3


func _physics_process(delta: float) -> void:
	_t += delta
	_tick_status(delta)
	velocity.y = minf(velocity.y + GRAVITY * delta, 900.0)
	var p := Game.inst.player
	var to_p := p.position.x - position.x
	var fast := 1.35 if phase == 2 else 1.0

	match state:
		S.SLEEP:
			velocity.x = 0.0
			if p.is_on_floor() and not p.is_dead():
				_go(S.INTRO)
				Game.inst.start_boss(self)
				Sfx.play("glas", 0.0, 0.5)
				Game.inst.shake(10.0)
		S.INTRO:
			if _t >= 1.6:
				_go(S.WALK)
		S.WALK:
			facing = 1 if to_p > 0.0 else -1
			velocity.x = facing * walk_speed * fast if absf(to_p) > 90.0 else 0.0
			if _t >= 0.9 / fast:
				_choose_attack(absf(to_p))
		S.SLAM_WIND:
			velocity.x = 0.0
			if _t >= 0.75 / fast:
				_go(S.SLAM)
				_slam()
		S.SLAM:
			if _t >= 0.2:
				_go(S.SLAM_REC)
		S.SLAM_REC:
			if _t >= 0.75 / fast:
				_go(S.WALK)
		S.THROW_WIND:
			velocity.x = 0.0
			facing = 1 if to_p > 0.0 else -1
			if _t >= 0.5 / fast:
				_throw(p.position)
				if phase == 2:
					_throw(p.position + Vector2(facing * 140.0, 0))
				_go(S.THROW_REC)
		S.THROW_REC:
			if _t >= 0.6:
				_go(S.WALK)
		S.SHUDDER:
			velocity.x = 0.0
			if _t >= 0.8:
				_wave_dir = 1 if to_p > 0.0 else -1
				_go(S.COLLAPSE)
				Sfx.play("mur", 0.0, 0.6)
		S.COLLAPSE:
			velocity.x = _wave_dir * wave_speed * fast
			if is_on_wall() or _t >= 1.7:
				_go(S.REFORM)
				velocity.x = 0.0
				Sfx.play("coup_lourd", 0.0, 0.5)
		S.REFORM:
			velocity.x = 0.0
			faces_open = [true, true, true]
			if _t >= 1.3:
				faces_open = [false, false, false]
				_face_timer = 0.4
				_go(S.WALK)
		S.DYING:
			velocity.x = 0.0
			if _t > 0.3 and randf() < 0.3:
				Game.inst.fx.sparks(position + Vector2(randf_range(-70, 70), randf_range(-90, 90)), 6, Color(0.6, 0.05, 0.05), 300.0, 1200.0, 0.7)
			if _t >= 2.4:
				Game.inst.boss_defeated(self)
				queue_free()
				return

	if state in [S.WALK, S.SLAM_WIND, S.SLAM, S.SLAM_REC, S.THROW_WIND, S.THROW_REC, S.SHUDDER]:
		_update_faces(delta)
	move_and_slide()
	if state not in [S.SLEEP, S.INTRO, S.REFORM, S.DYING]:
		_touch_player()
	queue_redraw()


func _choose_attack(dist: float) -> void:
	_attacks += 1
	if _attacks % (3 if phase == 2 else 4) == 0:
		_go(S.SHUDDER)
	elif dist < 210.0:
		_go(S.SLAM_WIND)
	else:
		_go(S.THROW_WIND if randf() < 0.6 else S.SLAM_WIND)


## Les visages s'ouvrent à tour de rôle : un seul à la fois, deux sous la moitié de sa vie.
func _update_faces(delta: float) -> void:
	_face_timer -= delta
	if _face_timer > 0.0:
		return
	var any_open := faces_open.has(true)
	if any_open:
		faces_open = [false, false, false]
		_face_timer = 0.7
	else:
		var order := [0, 1, 2]
		order.shuffle()
		for i in (2 if phase == 2 else 1):
			faces_open[order[i]] = true
		_face_timer = 3.2 if phase == 1 else 2.6
		Sfx.play("rate", -10.0, 1.6)


func _slam() -> void:
	Sfx.play("coup_lourd", 2.0, 0.6)
	Game.inst.shake(12.0)
	var feet := position.y + BODY.y * 0.5
	var at := position + Vector2(facing * 110.0, BODY.y * 0.5 - 20.0)
	Game.inst.fx.sparks(at, 24, Color(0.6, 0.55, 0.5), 380.0, 1400.0, 0.7)
	# Le coup lui-même, devant la masse
	var reach := Rect2(position + Vector2(-20 if facing > 0 else -170, BODY.y * 0.5 - 90), Vector2(190, 90))
	var p := Game.inst.player
	if reach.intersects(p.get_hurt_rect()):
		p.receive_attack(self, 2)
	# Une onde qui court au sol des deux côtés : il faut sauter par-dessus.
	for dir in [-1, 1]:
		var w := BossHazard.new()
		w.kind = "onde"
		w.velocity = Vector2(dir * (330.0 if phase == 1 else 400.0), 0)
		w.position = Vector2(at.x, feet - 17.0)
		get_parent().add_child(w)
	if phase == 2:
		var rampants := get_parent().get_children().filter(func(n): return n is Rampant)
		if rampants.size() < 2:
			var r := Rampant.new()
			r.position = position + Vector2(-facing * 60.0, BODY.y * 0.5 - 14.0)
			get_parent().add_child(r)
			Game.inst.fx.text(r.position + Vector2(0, -30), "un corps se détache", Color(0.8, 0.7, 0.65), 13)


func _throw(target: Vector2) -> void:
	var l := BossHazard.new()
	l.kind = "lanterne"
	l.life = 4.0
	l.position = position + Vector2(facing * 50.0, -BODY.y * 0.5)
	var dx := clampf(target.x - l.position.x, -520.0, 520.0)
	l.velocity = Vector2(dx / 0.9, -620.0)
	get_parent().add_child(l)
	Sfx.play("souffle", -4.0, 0.7)


func take_hit(info: Dictionary) -> String:
	if state in [S.SLEEP, S.INTRO, S.DYING]:
		return "none"
	var rect: Rect2 = info.get("rect", get_hurt_rect())
	var face_hit := false
	if state != S.COLLAPSE:
		for i in FACES.size():
			if faces_open[i] and _face_rect(i).intersects(rect):
				face_hit = true
				break
	if face_hit:
		var hit := info.duplicate()
		if state == S.REFORM:
			hit.damage = int(ceil(info.damage * 1.5))
		_apply_hit(hit)
		Sfx.play("blesse", -4.0, 0.7)
		if not dead and hp <= max_hp / 2 and phase == 1:
			phase = 2
			Game.inst.fx.text(position + Vector2(0, -BODY.y * 0.5 - 30), "Les visages hurlent", Color(0.9, 0.3, 0.25), 20)
			Sfx.play("glas", -2.0, 0.6)
		return "hit"
	# La masse encaisse : presque rien ne passe.
	var dmg := int(info.damage / 4)
	if dmg > 0:
		_damage(dmg, true)
	else:
		_flash = 0.05
	if randf() < 0.3:
		Game.inst.fx.text(position + Vector2(randf_range(-40, 40), -BODY.y * 0.5 - 10), "la chair se referme", Color(0.75, 0.7, 0.65), 13)
	return "guard"


func _die() -> void:
	dead = true
	hp = 0
	_burn = 0.0
	_bleed = 0.0
	faces_open = [false, false, false]
	collision_layer = 0
	remove_from_group("hittable")
	Sfx.play("glas", 2.0, 0.45)
	Game.inst.shake(16.0)
	for n in get_parent().get_children():
		if n is BossHazard or n is Rampant:
			n.queue_free()
	_go(S.DYING)


func _go(s: S) -> void:
	state = s
	_t = 0.0


func _face_rect(i: int) -> Rect2:
	var off: Vector2 = FACES[i]
	off.x *= facing
	return Rect2(position + off - FACE_SIZE * 0.5, FACE_SIZE)


func get_hurt_rect() -> Rect2:
	if state == S.COLLAPSE:
		return Rect2(position + Vector2(-WAVE.x * 0.5, BODY.y * 0.5 - WAVE.y), WAVE)
	return Rect2(position - BODY * 0.5, BODY)


func is_engaged() -> bool:
	return state != S.SLEEP


# =============================================================================
#  Dessin gris
# =============================================================================

func _draw() -> void:
	var base := Color(0.5, 0.42, 0.38)
	if state == S.SLEEP:
		base = base.darkened(0.3)
	var col := _body_color(base)
	var foot := BODY.y * 0.5

	if state == S.COLLAPSE or (state == S.REFORM and _t < 0.5):
		# La vague de corps qui roule au sol
		var k := 1.0 if state == S.COLLAPSE else 1.0 - _t / 0.5
		var h := WAVE.y * k + 20.0
		for i in 7:
			var x := -WAVE.x * 0.5 + i * WAVE.x / 6.0
			draw_circle(Vector2(x, foot - h * 0.5 + sin(_t * 14.0 + i) * 6.0), h * 0.5, col.darkened(0.05 * (i % 2)))
		return

	var grow := 1.0
	if state == S.INTRO:
		grow = clampf(_t / 1.2, 0.15, 1.0)
	elif state == S.REFORM:
		grow = clampf((_t - 0.3) / 0.8, 0.2, 1.0)
	elif state == S.DYING:
		grow = clampf(1.0 - _t / 2.4, 0.05, 1.0)
	var top := foot - BODY.y * grow
	# La masse : des corps empilés
	var lumps := [Vector2(-50, 70), Vector2(45, 72), Vector2(0, 40), Vector2(-45, 10), Vector2(42, -10),
		Vector2(-10, -30), Vector2(30, -60), Vector2(-30, -70), Vector2(0, -85)]
	for l in lumps:
		var y: float = foot - (foot - l.y) * grow
		draw_circle(Vector2(l.x * facing, y), 38.0 * maxf(grow, 0.4), col)
	if state == S.SHUDDER:
		var o := sin(_t * 70.0) * 4.0
		draw_rect(Rect2(-BODY.x * 0.5 - 4 + o, top - 4, BODY.x + 8, foot - top + 8), Color(1.0, 0.25, 0.2, 0.8), false, 3.0)
	# Pioche levée (signal du coup)
	var arm_base := Vector2(facing * 50, top + 40)
	var tip := arm_base + Vector2(facing * 70, -10)
	if state == S.SLAM_WIND:
		tip = arm_base + Vector2(facing * 10, -90)
		if int(_t * 20.0) % 2 == 0:
			draw_rect(Rect2(-BODY.x * 0.5 - 4, top - 4, BODY.x + 8, foot - top + 8), Color(1.0, 0.25, 0.2, 0.9), false, 3.0)
	elif state in [S.SLAM, S.SLAM_REC]:
		tip = arm_base + Vector2(facing * 100, foot - top - 50)
	if state not in [S.INTRO, S.DYING]:
		draw_line(arm_base, tip, Color(0.4, 0.33, 0.27), 6.0)
		var d := (tip - arm_base).normalized()
		var perp := Vector2(-d.y, d.x)
		draw_line(tip - perp * 18.0, tip + perp * 18.0 + d * 6.0, Color(0.65, 0.63, 0.6), 5.0)
	# Lanternes accrochées
	for lx in [-62, 66]:
		var lp := Vector2(lx * facing, top + 70 * grow)
		draw_line(lp + Vector2(0, -16), lp, Color(0.3, 0.27, 0.24), 2.0)
		draw_circle(lp + Vector2(0, 6), 8.0, Color(1.0, 0.62, 0.22, 0.95 if state != S.THROW_WIND else 0.5 + 0.5 * sin(_t * 40.0)))
	# Les visages
	if state not in [S.INTRO, S.DYING]:
		for i in FACES.size():
			var r := _face_rect(i)
			r.position -= position
			var c := r.get_center()
			if faces_open[i]:
				draw_circle(c, FACE_SIZE.x * 0.55, Color(0.92, 0.86, 0.78))
				draw_circle(c + Vector2(-8, -5), 4.0, Color(0.1, 0.08, 0.08))
				draw_circle(c + Vector2(8, -5), 4.0, Color(0.1, 0.08, 0.08))
				draw_arc(c + Vector2(0, 10), 7.0, PI, TAU, 8, Color(0.1, 0.08, 0.08), 3.0)
				# Les larmes : c'est là qu'il faut frapper
				for s in [-8, 8]:
					var ty := fmod(_t * 40.0 + s * 3.0, 18.0)
					draw_line(c + Vector2(s, -1 + ty * 0.2), c + Vector2(s, 3 + ty), Color(0.6, 0.85, 1.0), 2.0)
			else:
				draw_arc(c, FACE_SIZE.x * 0.4, 0.2, PI - 0.2, 8, col.darkened(0.35), 3.0)
	_draw_wounds(top)
