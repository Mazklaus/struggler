class_name Soldier
extends CharacterBody2D
## Soldat déserteur : avance bouclier levé, prévient avant de frapper d'estoc,
## reste ouvert après son coup. Lisible, pour tester le rythme du combat.

enum S { PATROL, CHASE, WINDUP, STRIKE, RECOVER, STAGGER, DOWN, DEAD }

@export var max_hp := 18
@export var walk_speed := 60.0
@export var chase_speed := 95.0
@export var windup_time := 0.5
@export var recover_time := 0.65
@export var lunge_speed := 340.0
@export var guard_limit := 4      # coups encaissés sur le bouclier avant qu'il cède
@export var respawn_time := 6.0

const BODY := Vector2(30, 58)
const GRAVITY := 1900.0

var state := S.PATROL
var facing := -1
var hp := 18
var guard_up := false

var _t := 0.0
var _spawn := Vector2.ZERO
var _attack_cd := 0.5
var _combo_left := 0
var _strike_hit := false
var _guard_hits := 0
var _burn := 0.0
var _burn_tick := 0.0
var _flash := 0.0
var _down_time := 1.6


func _ready() -> void:
	hp = max_hp
	_spawn = position
	add_to_group("hittable")
	add_to_group("trempe")
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = BODY
	shape.shape = box
	add_child(shape)
	z_index = 4


func _physics_process(delta: float) -> void:
	_t += delta
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	_update_burn(delta)
	velocity.y = minf(velocity.y + GRAVITY * delta, 900.0)

	var p := Game.inst.player
	var to_p := p.position - position
	var dist := absf(to_p.x)
	var sees := dist < 360.0 and absf(to_p.y) < 110.0 and not p.is_dead()

	match state:
		S.PATROL:
			guard_up = false
			velocity.x = facing * walk_speed
			if absf(position.x - _spawn.x) > 120.0 and signf(position.x - _spawn.x) == facing:
				facing = -facing
			if is_on_wall():
				facing = -facing
			if sees:
				_go(S.CHASE)
		S.CHASE:
			facing = 1 if to_p.x > 0.0 else -1
			guard_up = true
			if dist > 80.0:
				velocity.x = move_toward(velocity.x, facing * chase_speed, 900.0 * delta)
			else:
				velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if dist < 100.0 and _attack_cd <= 0.0 and absf(to_p.y) < 60.0:
				_combo_left = 1 if randf() < 0.35 else 0
				_go(S.WINDUP)
			elif not sees and dist > 520.0:
				_go(S.PATROL)
		S.WINDUP:
			guard_up = false
			velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
			if _t >= windup_time:
				_strike_hit = false
				velocity.x = facing * lunge_speed
				_go(S.STRIKE)
		S.STRIKE:
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			if not _strike_hit:
				_check_strike()
			if _t >= 0.14:
				_go(S.RECOVER)
		S.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
			if _t >= recover_time:
				if _combo_left > 0:
					_combo_left -= 1
					_go(S.WINDUP)
					_t = windup_time * 0.35   # second coup plus rapide
				else:
					_attack_cd = randf_range(0.6, 1.3)
					_go(S.CHASE)
		S.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			if _t >= 0.22:
				_attack_cd = maxf(_attack_cd, 0.25)
				_go(S.CHASE)
		S.DOWN:
			guard_up = false
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if _t >= _down_time:
				_guard_hits = 0
				_attack_cd = 0.4
				_go(S.CHASE)
		S.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if _t >= respawn_time:
				_respawn()

	move_and_slide()
	queue_redraw()


func _check_strike() -> void:
	var reach := Rect2(position + Vector2(10 if facing > 0 else -88, -22), Vector2(78, 30))
	if not reach.intersects(Game.inst.player.get_hurt_rect()):
		return
	_strike_hit = true
	var res: String = Game.inst.player.receive_attack(self, 1)
	if res == "contre":
		_knock_down(1.8)
		velocity.x = -facing * 220.0


func _update_burn(delta: float) -> void:
	if _burn <= 0.0 or state == S.DEAD:
		return
	_burn -= delta
	_burn_tick -= delta
	if _burn_tick <= 0.0:
		_burn_tick = 0.5
		_damage(1, false)
		Game.inst.fx.sparks(position + Vector2(randf_range(-10, 10), -10), 3, Color(1.0, 0.55, 0.15), 120.0, -200.0, 0.5)


func take_hit(info: Dictionary) -> String:
	if state == S.DEAD:
		return "none"
	var from_front := signf(info.source_x - position.x) == facing
	if guard_up and from_front and state == S.CHASE:
		if info.guard_break:
			Sfx.play("garde", 0.0, 0.7)
			Game.inst.fx.text(position + Vector2(0, -60), "Garde brisée", Color(1.0, 0.75, 0.4), 16)
			_damage(info.damage, true)
			if state != S.DEAD:
				_knock_down(1.6)
				velocity.x = info.dir.x * 260.0
			return "hit"
		_guard_hits += 1
		Sfx.play("garde", -2.0)
		velocity.x = info.dir.x * 140.0
		if _guard_hits >= guard_limit:
			Game.inst.fx.text(position + Vector2(0, -60), "Bouclier fendu", Color(1.0, 0.75, 0.4), 16)
			_knock_down(1.3)
		return "guard"

	var dmg: int = info.damage
	if state == S.DOWN:
		dmg = int(ceil(dmg * 1.5))
	if info.burn:
		_burn = 2.0
		_burn_tick = 0.5
	_damage(dmg, true)
	if state == S.DEAD:
		return "hit"
	if info.blanc or (info.heavy and info.charge >= 0.99):
		_knock_down(1.5)
		velocity = Vector2(info.dir.x * 380.0, -220.0)
	elif state == S.DOWN:
		pass
	elif state in [S.WINDUP, S.STRIKE] and not info.heavy:
		# Les coups légers n'interrompent pas une attaque lancée : il faut esquiver ou contrer.
		velocity.x += info.dir.x * 40.0
	else:
		_go(S.STAGGER)
		velocity.x = info.dir.x * (240.0 if info.heavy else 150.0)
		if info.dir.y < -0.9:
			velocity.y = -200.0
	return "hit"


func _damage(amount: int, popup: bool) -> void:
	hp -= amount
	_flash = 0.08
	if popup:
		Game.inst.fx.text(position + Vector2(randf_range(-10, 10), -44), str(amount), Color(1, 1, 1), 16)
	if hp <= 0:
		_die()


func _knock_down(duration: float) -> void:
	_down_time = duration
	guard_up = false
	_go(S.DOWN)


func _die() -> void:
	hp = 0
	_burn = 0.0
	_go(S.DEAD)
	Sfx.play("coup_lourd", 0.0, 0.8)
	Game.inst.fx.sparks(position, 30, Color(0.6, 0.05, 0.05), 380.0, 1300.0, 0.9)
	Game.inst.add_blood(position + Vector2(0, BODY.y * 0.5))
	collision_layer = 0


func _respawn() -> void:
	position = _spawn
	velocity = Vector2.ZERO
	hp = max_hp
	_guard_hits = 0
	collision_layer = 4
	_go(S.PATROL)


func _go(s: S) -> void:
	state = s
	_t = 0.0


func can_quench() -> bool:
	return state == S.DOWN


func get_hurt_rect() -> Rect2:
	if state == S.DOWN:
		return Rect2(position + Vector2(-BODY.y * 0.5, BODY.y * 0.5 - 22), Vector2(BODY.y, 22))
	return Rect2(position - BODY * 0.5, BODY)


func _draw() -> void:
	if state == S.DEAD:
		if _t < 1.0:
			draw_rect(Rect2(-BODY.y * 0.5, BODY.y * 0.5 - 14, BODY.y, 14), Color(0.35, 0.2, 0.2, 1.0 - _t))
		return
	var col := Color(0.55, 0.5, 0.58)
	if _flash > 0.0:
		col = Color(1, 1, 1)
	elif _burn > 0.0:
		col = col.lerp(Color(1.0, 0.5, 0.15), 0.35)
	var r := get_hurt_rect()
	r.position -= position
	draw_rect(r, col)

	if state == S.DOWN:
		var k := clampf(_t / _down_time, 0.0, 1.0)
		draw_rect(Rect2(-24, r.position.y - 10, 48 * (1.0 - k), 4), Color(0.9, 0.85, 0.7, 0.8))
		draw_string(ThemeDB.fallback_font, Vector2(-32, r.position.y - 16), "à terre", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.8, 0.6))
		return

	draw_rect(Rect2(facing * 6 - 4, -22, 8, 6), Color(0.15, 0.12, 0.15))
	# Lance
	var spear_len := 56.0
	var sx := facing * 10.0
	var sy := -6.0
	if state == S.WINDUP:
		sx = -facing * 14.0
		var k := _t / windup_time
		# Signal d'attaque : clignote de plus en plus vite.
		if int(_t * (10.0 + 20.0 * k)) % 2 == 0:
			draw_rect(Rect2(-BODY.x * 0.5 - 3, -BODY.y * 0.5 - 3, BODY.x + 6, BODY.y + 6), Color(1.0, 0.25, 0.2, 0.9), false, 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(-4, -BODY.y * 0.5 - 10), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.3, 0.2))
	elif state == S.STRIKE:
		sx = facing * 40.0
	draw_line(Vector2(sx - facing * 20.0, sy), Vector2(sx + facing * spear_len, sy), Color(0.4, 0.33, 0.25), 3.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(sx + facing * spear_len, sy - 5), Vector2(sx + facing * (spear_len + 14), sy),
		Vector2(sx + facing * spear_len, sy + 5)]), Color(0.75, 0.75, 0.78))
	# Bouclier
	if guard_up:
		var crack := float(_guard_hits) / guard_limit
		var sc := Color(0.6, 0.55, 0.45).lerp(Color(0.35, 0.25, 0.2), crack)
		draw_rect(Rect2(facing * 16 - 5, -24, 10, 40), sc)
	# Vie
	var w := 36.0
	draw_rect(Rect2(-w * 0.5, -BODY.y * 0.5 - 18, w, 4), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(-w * 0.5, -BODY.y * 0.5 - 18, w * hp / max_hp, 4), Color(0.75, 0.15, 0.15))
