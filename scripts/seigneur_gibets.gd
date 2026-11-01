class_name SeigneurGibets
extends Enemy
## Le Seigneur des gibets : un déserteur devenu apôtre, qui règne sur le Grand Gibet.
## Long et voûté, la peau grise tendue sur des os de bois, il porte une gaffe de bourreau.
## Il fauche à la gaffe, fait tomber des nœuds coulants des branches du chêne (une ombre
## au sol prévient), et saute dans l'arbre pour retomber sur Wendel. Sous la moitié de sa
## vie, les pendus se détachent des branches et tombent.

enum S { SLEEP, INTRO, WALK, SWEEP_WIND, SWEEP, SWEEP_REC, NOOSE_WIND, NOOSE_REC, LEAP, PERCH, DROP, DROP_REC, DYING }

const ID := "gibets"
const NAME := "Le Seigneur des gibets"
const BODY := Vector2(60, 150)
const GRAVITY := 1900.0

@export var walk_speed := 70.0

var state := S.SLEEP
var phase := 1
var _t := 0.0
var _attacks := 0
var _swept := false
var _drop_x := 0.0
var _home_y := 0.0
var _rain := 2.5


func _ready() -> void:
	max_hp = 80
	scrap_drop = 0
	contact_damage = 1
	body_size = BODY
	super._ready()
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(44, 60)
	shape.shape = box
	shape.position.y = BODY.y * 0.5 - 30.0
	add_child(shape)
	z_index = 3


func _physics_process(delta: float) -> void:
	_t += delta
	_tick_status(delta)
	var p := Game.inst.player
	var to_p := p.position.x - position.x
	var fast := 1.3 if phase == 2 else 1.0
	if state not in [S.LEAP, S.PERCH]:
		velocity.y = minf(velocity.y + GRAVITY * delta, 900.0)

	match state:
		S.SLEEP:
			velocity.x = 0.0
			if p.is_on_floor() and not p.is_dead() and absf(to_p) < 520.0:
				_go(S.INTRO)
				_home_y = position.y
				Game.inst.start_boss(self)
				Sfx.play("glas", 0.0, 0.4)
				Game.inst.shake(8.0)
		S.INTRO:
			if _t >= 1.8:
				_go(S.WALK)
		S.WALK:
			facing = 1 if to_p > 0.0 else -1
			velocity.x = facing * walk_speed * fast if absf(to_p) > 120.0 else 0.0
			if _t >= 0.8 / fast:
				_choose_attack(absf(to_p))
		S.SWEEP_WIND:
			velocity.x = 0.0
			if _t >= 0.6 / fast:
				_go(S.SWEEP)
				_swept = false
				Sfx.play("souffle", 0.0, 0.6)
		S.SWEEP:
			velocity.x = facing * 260.0
			if not _swept and _t >= 0.08:
				_swept = true
				var reach := Rect2(position + Vector2(-10 if facing > 0 else -200, -10), Vector2(210, 80))
				if reach.intersects(p.get_hurt_rect()):
					p.receive_attack(self, 2)
			if _t >= 0.25:
				_go(S.SWEEP_REC)
		S.SWEEP_REC:
			velocity.x = 0.0
			if _t >= 0.7 / fast:
				_go(S.WALK)
		S.NOOSE_WIND:
			velocity.x = 0.0
			if _t >= 0.5:
				var n := 3 if phase == 1 else 5
				for i in n:
					var off := (i - (n - 1) * 0.5) * 150.0
					_noose(p.position.x + off, 0.8 + i * 0.12)
				_go(S.NOOSE_REC)
		S.NOOSE_REC:
			if _t >= 1.4:
				_go(S.WALK)
		S.LEAP:
			# Il s'arrache du sol et disparaît dans les branches.
			velocity = Vector2(0, -900.0)
			if position.y < _home_y - 420.0:
				_go(S.PERCH)
				velocity = Vector2.ZERO
		S.PERCH:
			_drop_x = p.position.x
			position.x = move_toward(position.x, _drop_x, 500.0 * delta)
			if _t >= 1.0 / fast:
				_go(S.DROP)
		S.DROP:
			velocity = Vector2(0, 1100.0)
			if is_on_floor():
				_land()
				_go(S.DROP_REC)
		S.DROP_REC:
			velocity.x = 0.0
			if _t >= 0.9 / fast:
				_go(S.WALK)
		S.DYING:
			velocity.x = 0.0
			if _t > 0.3 and randf() < 0.3:
				Game.inst.fx.sparks(position + Vector2(randf_range(-30, 30), randf_range(-70, 70)), 6, Color(0.5, 0.45, 0.4), 300.0, 1200.0, 0.7)
			if _t >= 2.4:
				Game.inst.boss_defeated(self)
				queue_free()
				return

	# Sous la moitié de sa vie, les pendus tombent des branches.
	if phase == 2 and state not in [S.SLEEP, S.INTRO, S.DYING]:
		_rain -= delta
		if _rain <= 0.0:
			_rain = randf_range(2.0, 3.0)
			var b := BossHazard.new()
			b.kind = "pendu"
			b.life = 3.0
			b.position = Vector2(clampf(p.position.x + randf_range(-220, 220), 120.0, Game.inst.room.size.x - 120.0), position.y - 360.0)
			get_parent().add_child(b)

	if state == S.PERCH:
		position.y = _home_y - 420.0
	else:
		move_and_slide()
	if state not in [S.SLEEP, S.INTRO, S.LEAP, S.PERCH, S.DYING]:
		_touch_player()
	queue_redraw()


func _choose_attack(dist: float) -> void:
	_attacks += 1
	if _attacks % 4 == 0:
		_go(S.LEAP)
		Sfx.play("souffle", 2.0, 0.5)
	elif dist < 220.0:
		_go(S.SWEEP_WIND)
	else:
		_go(S.NOOSE_WIND if randf() < 0.65 else S.SWEEP_WIND)


func _noose(x: float, delay: float) -> void:
	var n := BossHazard.new()
	n.kind = "noeud"
	n.life = delay + 0.45
	n.delay = delay
	var floor_y := Game.inst.floor_below(Vector2(x, position.y - 40.0))
	n.position = Vector2(x, floor_y - 120.0)
	get_parent().add_child(n)


func _land() -> void:
	Sfx.play("coup_lourd", 2.0, 0.5)
	Game.inst.shake(12.0)
	var feet := position.y + BODY.y * 0.5
	Game.inst.fx.sparks(Vector2(position.x, feet), 24, Color(0.55, 0.5, 0.45), 380.0, 1400.0, 0.7)
	var p := Game.inst.player
	if get_hurt_rect().grow(20).intersects(p.get_hurt_rect()):
		p.receive_attack(self, 2)
	for dir in [-1, 1]:
		var w := BossHazard.new()
		w.kind = "onde"
		w.velocity = Vector2(dir * (320.0 if phase == 1 else 390.0), 0)
		w.position = Vector2(position.x, feet - 17.0)
		get_parent().add_child(w)


func take_hit(info: Dictionary) -> String:
	if state in [S.SLEEP, S.INTRO, S.DYING, S.PERCH]:
		return "none"
	if not _apply_hit(info):
		return "none"
	Sfx.play("blesse", -4.0, 0.6)
	if not dead and hp <= max_hp / 2 and phase == 1:
		phase = 2
		Game.inst.fx.text(position + Vector2(0, -BODY.y * 0.5 - 30), "Les pendus se détachent", Color(0.85, 0.8, 0.7), 20)
		Sfx.play("glas", -2.0, 0.5)
	return "hit"


func _die() -> void:
	dead = true
	hp = 0
	_burn = 0.0
	_bleed = 0.0
	collision_layer = 0
	remove_from_group("hittable")
	Sfx.play("glas", 2.0, 0.4)
	Game.inst.shake(14.0)
	for n in get_parent().get_children():
		if n is BossHazard:
			n.queue_free()
	_go(S.DYING)


func _go(s: S) -> void:
	state = s
	_t = 0.0


func is_engaged() -> bool:
	return state != S.SLEEP


func _draw() -> void:
	var skin := _body_color(Color(0.5, 0.48, 0.44))
	var cloth := _body_color(Color(0.28, 0.25, 0.22))
	var h := BODY.y * 0.5
	var stoop := 10.0 * facing
	if state == S.DYING:
		skin.a = clampf(1.0 - _t / 2.4, 0.0, 1.0)
		cloth.a = skin.a
	# jambes longues comme des poteaux
	draw_rect(Rect2(-16, h - 50, 10, 50), cloth)
	draw_rect(Rect2(6, h - 50, 10, 50), cloth)
	# le corps voûté, en haillons d'uniforme
	draw_colored_polygon(PackedVector2Array([Vector2(-22, h - 50), Vector2(22, h - 50), Vector2(18 + stoop, -h + 34), Vector2(-18 + stoop, -h + 34)]), cloth)
	# la tête, penchée, la corde encore au cou
	var head := Vector2(stoop * 1.6, -h + 22)
	draw_circle(head, 14.0, skin)
	draw_line(head + Vector2(-10, 10), head + Vector2(10, 12), Color(0.55, 0.45, 0.3), 3.0)
	draw_line(head + Vector2(0, 12), head + Vector2(-facing * 8, 40), Color(0.55, 0.45, 0.3), 2.0)
	# la gaffe de bourreau : un long manche et un croc
	var hand := Vector2(facing * 20 + stoop, -h + 60)
	var tip := hand + Vector2(facing * 70, -80)
	if state == S.SWEEP_WIND:
		tip = hand + Vector2(-facing * 60, -90)
	elif state == S.SWEEP:
		tip = hand + Vector2(facing * 120, 30)
	draw_line(hand + (hand - tip) * 0.4, tip, Color(0.4, 0.32, 0.22), 5.0)
	draw_arc(tip + Vector2(facing * 8, 0), 10.0, PI * 0.5, PI * 1.6, 8, Color(0.45, 0.45, 0.47), 4.0)
	if state == S.NOOSE_WIND:
		draw_line(hand, hand + Vector2(0, -70), skin, 6.0)
	_draw_wounds(-h)
