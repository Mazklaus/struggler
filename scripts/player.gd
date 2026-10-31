class_name Player
extends CharacterBody2D
## Wendel, version prototype : déplacements nerveux, marteau lent, combat en Cadence.

enum S { NORMAL, ATTACK, CHARGE, DASH, SLIDE, PARRY, HEAL, QUENCH, HURT, DEAD }

# --- Déplacements -----------------------------------------------------------
@export var run_speed := 270.0
@export var ground_accel := 2600.0
@export var ground_decel := 3200.0
@export var air_accel := 1900.0
@export var gravity := 1900.0
@export var fall_gravity_mult := 1.3
@export var max_fall := 950.0
@export var jump_velocity := -640.0
@export var jump_cut := 0.45          # relâcher le saut tôt = saut plus court
@export var coyote_time := 0.1
@export var jump_buffer := 0.12
@export var dash_speed := 620.0
@export var dash_time := 0.17
@export var dash_cooldown := 0.3
@export var slide_speed := 470.0
@export var slide_time := 0.42
@export var pogo_velocity := -560.0

# --- Cadence -----------------------------------------------------------------
@export var beat := 0.5               # écart idéal entre deux frappes (secondes)
@export var tolerance := 0.13         # marge autour du temps idéal
@export var heat_on_hit := 20.0       # Chaleur gagnée par une frappe en cadence qui touche
@export var heat_on_whiff := 8.0      # ... qui ne touche rien
@export var heat_break := 12.0        # Chaleur perdue quand on casse le rythme
@export var heat_decay := 30.0        # par seconde, quand on ne frappe plus
@export var heat_grace := 1.1         # délai avant que la Chaleur retombe
@export var heat_after_blanc := 67.0  # Chaleur restante après une Frappe à blanc (palier 2)

# --- Vie, Rage, outils -------------------------------------------------------
@export var max_hp := 7
@export var max_rage := 100.0
@export var heal_cost := 33.0
@export var heal_time := 1.0
@export var parry_window := 0.18
@export var quench_haste_time := 3.0

const BODY := Vector2(28, 56)
const SLIDE_BODY := Vector2(28, 24)

var state := S.NORMAL
var facing := 1
var hp := 7
var rage := 0.0
var heat := 0.0
var spawn_point := Vector2.ZERO

var _shape: CollisionShape2D
var _box: RectangleShape2D
var _state_time := 0.0
var _coyote := 0.0
var _jump_buf := 0.0
var _attack_buf := 0.0
var _attack_buf_press := 0
var _attack_buf_dir := 0
var _attack_buf_cadence := false
var _dash_cd := 0.0
var _air_dash := true
var _invuln := 0.0
var _haste := 0.0
var _safe_pos := Vector2.ZERO
var _was_on_floor := false

# Attaque en cours
var _atk := {}
var _combo := 0
var _last_atk_end := -10.0
var _last_strike_usec := -1     # temps réel de la dernière frappe (pour la Cadence)
var _tick_pending := false
var _charge := 0.0

var streak := 0
var last_judgment := ""
var judgment_time := 0.0


func _ready() -> void:
	hp = max_hp
	_box = RectangleShape2D.new()
	_box.size = BODY
	_shape = CollisionShape2D.new()
	_shape.shape = _box
	add_child(_shape)
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 6.0
	_safe_pos = position
	z_index = 5


# =============================================================================
#  Boucle principale
# =============================================================================

func _physics_process(delta: float) -> void:
	_state_time += delta
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_invuln = maxf(_invuln - delta, 0.0)
	_haste = maxf(_haste - delta, 0.0)
	_jump_buf = maxf(_jump_buf - delta, 0.0)
	_attack_buf = maxf(_attack_buf - delta, 0.0)

	if Input.is_action_just_pressed("saut"):
		_jump_buf = jump_buffer
	if Input.is_action_just_pressed("attaque"):
		_attack_buf = 0.22
		_attack_buf_press = Time.get_ticks_usec()
		_attack_buf_dir = _aim()
		# Le tempo se juge à l'appui : une frappe lancée trop tôt casse le rythme
		# même si elle ne part qu'à la fin du coup précédent.
		_attack_buf_cadence = _judge(_attack_buf_press)

	if is_on_floor():
		_coyote = coyote_time
		_air_dash = true
	else:
		_coyote = maxf(_coyote - delta, 0.0)

	match state:
		S.NORMAL: _st_normal(delta)
		S.ATTACK: _st_attack(delta)
		S.CHARGE: _st_charge(delta)
		S.DASH: _st_dash(delta)
		S.SLIDE: _st_slide(delta)
		S.PARRY: _st_simple(delta, 0.4)
		S.HEAL: _st_heal(delta)
		S.QUENCH: _st_quench(delta)
		S.HURT: _st_hurt(delta)
		S.DEAD: _st_dead(delta)

	move_and_slide()

	if is_on_floor() and not _was_on_floor and velocity.y >= 0.0:
		Game.inst.fx.sparks(position + Vector2(0, 28), 3, Color(0.6, 0.58, 0.52), 90.0, 300.0, 0.25)
	_was_on_floor = is_on_floor()
	if is_on_floor() and state != S.DEAD and not _over_hazard_edge():
		_safe_pos = position

	_check_hazards()
	_update_heat(delta)
	queue_redraw()


func _process(_delta: float) -> void:
	# Le signal d'enclume tombe pile au moment où il faut frapper de nouveau.
	if _tick_pending and Time.get_ticks_usec() >= _last_strike_usec + int(beat * 1_000_000.0):
		_tick_pending = false
		Sfx.play("enclume_doux", -4.0)


# =============================================================================
#  États
# =============================================================================

func _st_normal(delta: float) -> void:
	_apply_gravity(delta)
	_run(delta, 1.0)

	if _jump_buf > 0.0 and _coyote > 0.0:
		_jump()
	if Input.is_action_just_released("saut") and velocity.y < 0.0:
		velocity.y *= jump_cut

	if _attack_buf > 0.0:
		_start_attack(_attack_buf_dir, _attack_buf_cadence)
	elif Input.is_action_just_pressed("lourde"):
		_set_state(S.CHARGE)
		_charge = 0.0
	elif Input.is_action_just_pressed("ruee"):
		_try_dash()
	elif Input.is_action_just_pressed("glissade") and is_on_floor():
		_start_slide()
	elif Input.is_action_just_pressed("contre"):
		_set_state(S.PARRY)
		velocity.x = 0.0
		Sfx.play("souffle", -8.0, 1.4)
	elif Input.is_action_just_pressed("panser"):
		_try_heal()
	elif Input.is_action_just_pressed("trempe"):
		_try_quench()


func _st_attack(delta: float) -> void:
	_apply_gravity(delta)
	var a := _atk
	var t := _state_time
	# Au sol, Wendel se plante pour frapper ; en l'air il garde son élan.
	if is_on_floor():
		_run(delta, 0.25 if t < a.windup + a.active else 0.5)
	else:
		_run(delta, 0.8)
	if Input.is_action_just_released("saut") and velocity.y < 0.0:
		velocity.y *= jump_cut

	if t >= a.windup and t < a.windup + a.active:
		if not a.started:
			a.started = true
			_on_active_start()
		_resolve_hits()
	elif t >= a.windup + a.active and not a.ended:
		a.ended = true
		if a.cadence and not a.heat_given:
			_add_heat(heat_on_whiff)
			a.heat_given = true

	var total: float = a.windup + a.active + a.recovery
	# La ruée annule la fin d'une frappe, comme dans Silksong.
	if t >= a.windup + a.active and Input.is_action_just_pressed("ruee"):
		_last_atk_end = _now()
		_try_dash()
		return
	if t >= total:
		_last_atk_end = _now()
		_set_state(S.NORMAL)
		if _attack_buf > 0.0:
			_start_attack(_attack_buf_dir, _attack_buf_cadence)


func _st_charge(delta: float) -> void:
	_apply_gravity(delta)
	_run(delta, 0.15)
	var was := _charge
	_charge = minf(_charge + delta / 0.6, 1.0)
	if _charge >= 1.0 and was < 1.0:
		Sfx.play("enclume_doux", -6.0, 0.7)
	if not Input.is_action_pressed("lourde"):
		_start_attack(3, _judge(Time.get_ticks_usec()))
	elif Input.is_action_just_pressed("ruee"):
		_try_dash()


func _st_dash(_delta: float) -> void:
	velocity = Vector2(facing * dash_speed * _speed_mult(), 0.0)
	if _state_time >= dash_time:
		velocity.x = facing * run_speed * _speed_mult()
		_set_state(S.NORMAL)
	elif _state_time > 0.06 and _attack_buf > 0.0:
		_start_attack(_attack_buf_dir, _attack_buf_cadence)


func _st_slide(delta: float) -> void:
	_apply_gravity(delta)
	var k := 1.0 - _state_time / slide_time
	velocity.x = facing * slide_speed * _speed_mult() * maxf(k, 0.35)
	if _state_time >= slide_time or not is_on_floor():
		if _can_stand():
			_set_body(BODY)
			_set_state(S.NORMAL)
		else:
			# Encore sous le plafond : on continue à glisser.
			_state_time = slide_time * 0.6
	elif _jump_buf > 0.0 and _can_stand():
		_set_body(BODY)
		_set_state(S.NORMAL)
		_jump()


func _st_simple(delta: float, duration: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, ground_decel * delta)
	if _state_time >= duration:
		_set_state(S.NORMAL)


func _st_heal(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = 0.0
	if _state_time >= heal_time:
		hp = mini(hp + 3, max_hp)
		Sfx.play("panse")
		Game.inst.fx.text(position + Vector2(0, -50), "+3 PV", Color(0.95, 0.92, 0.85), 18)
		Game.inst.fx.sparks(position, 10, Color(0.95, 0.92, 0.85), 160.0, -200.0, 0.6)
		_set_state(S.NORMAL)


func _st_quench(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = 0.0
	if _state_time >= 0.35:
		_set_state(S.NORMAL)


func _st_hurt(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	if _state_time >= 0.3:
		_set_state(S.NORMAL)


func _st_dead(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	if _state_time >= 1.4:
		position = spawn_point
		velocity = Vector2.ZERO
		hp = max_hp
		rage = 0.0   # à la mort, la Rage est perdue
		heat = 0.0
		_invuln = 1.0
		_set_state(S.NORMAL)


# =============================================================================
#  Déplacements
# =============================================================================

func _aim() -> int:
	# 0 = devant, 1 = haut, 2 = bas (en l'air seulement)
	if Input.is_action_pressed("haut"):
		return 1
	if Input.is_action_pressed("bas") and not is_on_floor():
		return 2
	return 0


func _input_x() -> float:
	return Input.get_axis("gauche", "droite")


func _speed_mult() -> float:
	return 1.35 if _haste > 0.0 else 1.0


func _run(delta: float, control: float) -> void:
	var dir := _input_x()
	if absf(dir) > 0.2 and state in [S.NORMAL, S.CHARGE]:
		facing = 1 if dir > 0.0 else -1
	var target := dir * run_speed * _speed_mult() * control
	var accel := ground_accel if is_on_floor() else air_accel
	if absf(dir) < 0.2:
		accel = ground_decel if is_on_floor() else air_accel * 0.6
	velocity.x = move_toward(velocity.x, target, accel * delta)


func _apply_gravity(delta: float) -> void:
	var g := gravity
	if velocity.y > 0.0:
		g *= fall_gravity_mult
	elif not Input.is_action_pressed("saut"):
		g *= 1.15
	velocity.y = minf(velocity.y + g * delta, max_fall)


func _jump() -> void:
	velocity.y = jump_velocity
	_jump_buf = 0.0
	_coyote = 0.0
	Sfx.play("souffle", -14.0, 0.8)


func _try_dash() -> void:
	if _dash_cd > 0.0 or (not is_on_floor() and not _air_dash):
		_set_state(S.NORMAL)
		return
	var dir := _input_x()
	if absf(dir) > 0.2:
		facing = 1 if dir > 0.0 else -1
	if not is_on_floor():
		_air_dash = false
	_dash_cd = dash_cooldown + dash_time
	_invuln = maxf(_invuln, dash_time + 0.03)
	_set_state(S.DASH)
	Sfx.play("souffle", -6.0, 1.1)
	Game.inst.fx.sparks(position + Vector2(-facing * 14, 20), 5, Color(0.7, 0.68, 0.62), 120.0, 0.0, 0.25)


func _start_slide() -> void:
	var dir := _input_x()
	if absf(dir) > 0.2:
		facing = 1 if dir > 0.0 else -1
	_set_body(SLIDE_BODY)
	_set_state(S.SLIDE)
	Sfx.play("souffle", -8.0, 0.7)


func _set_body(size: Vector2) -> void:
	if _box.size == size:
		return
	# Les pieds restent au même endroit.
	_box.size = size
	_shape.position.y = (BODY.y - size.y) * 0.5


func _can_stand() -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	var probe := RectangleShape2D.new()
	probe.size = BODY - Vector2(2, 2)
	q.shape = probe
	q.transform = Transform2D(0.0, global_position)
	q.collision_mask = 1
	return get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


func _over_hazard_edge() -> bool:
	var feet := Rect2(position + Vector2(-40, 20), Vector2(80, 30))
	for r in Game.inst.hazard_rects:
		if feet.intersects(r):
			return true
	return false


func _check_hazards() -> void:
	if state == S.DEAD:
		return
	var body := get_hurt_rect()
	for r in Game.inst.hazard_rects:
		if body.intersects(r):
			# Les pics blessent et renvoient sur le dernier sol sûr.
			_hurt(1, position + Vector2(0, 40), true)
			if state != S.DEAD:
				position = _safe_pos
				velocity = Vector2.ZERO
			return


# =============================================================================
#  Combat : frappes et Cadence
# =============================================================================

func _start_attack(dir: int, cadence: bool) -> void:
	_attack_buf = 0.0
	if dir == 2 and is_on_floor():
		dir = 0
	var now := _now()
	_combo = (_combo + 1) % 3 if now - _last_atk_end < 0.35 else 0
	var heavy := dir == 3
	var blanc := heat >= 100.0

	var a := {
		"dir": dir, "heavy": heavy, "blanc": blanc, "charge": _charge if heavy else 0.0,
		"windup": 0.09, "active": 0.07, "recovery": 0.24,
		"hit": [], "started": false, "ended": false, "cadence": cadence, "heat_given": false,
		"connected": false,
	}
	if heavy:
		a.windup = 0.1
		a.active = 0.09
		a.recovery = 0.38
	elif dir == 2:
		a.windup = 0.05
		a.active = 0.2
		a.recovery = 0.12
	elif _combo == 2:
		a.windup = 0.12
		a.recovery = 0.28
	if blanc:
		a.windup = 0.14
		a.active = 0.1
		a.recovery = 0.32
	if _haste > 0.0:
		a.recovery *= 0.7

	_atk = a
	if not heavy:
		_charge = 0.0
	_set_state(S.ATTACK)


## Juge le tempo d'une frappe par rapport à la précédente. Renvoie vrai si elle est en cadence.
func _judge(press_usec: int) -> bool:
	var first := _last_strike_usec < 0
	var dt := (press_usec - _last_strike_usec) / 1_000_000.0
	_last_strike_usec = press_usec
	_tick_pending = true
	if first or dt > beat + 0.4:
		streak = 0
		return false
	if absf(dt - beat) <= tolerance:
		streak += 1
		_show_judgment("En cadence" if absf(dt - beat) > tolerance * 0.4 else "Parfait")
		Sfx.play("cadence", -6.0, 1.0 + minf(streak, 6) * 0.04)
		return true
	streak = 0
	heat = maxf(heat - heat_break, 0.0)
	_show_judgment("Trop tôt" if dt < beat else "Trop tard")
	Sfx.play("rate", -6.0)
	return false


func _show_judgment(text: String) -> void:
	last_judgment = text
	judgment_time = _now()


func _on_active_start() -> void:
	var a := _atk
	if a.blanc:
		Sfx.play("glas", 2.0)
		Game.inst.shake(14.0)
		Game.inst.hitstop(0.12)
		Game.inst.fx.sparks(position + Vector2(facing * 30, 0), 60, Color(1.0, 0.95, 0.75), 700.0, 600.0, 0.8)
		Game.inst.fx.sparks(position + Vector2(facing * 30, 0), 40, Color(1.0, 0.55, 0.15), 500.0, 800.0, 0.7)
		Game.inst.fx.text(position + Vector2(0, -70), "FRAPPE À BLANC", Color(1.0, 0.95, 0.8), 22)
		# Le marteau ne refroidit pas d'un coup : il retombe au palier brise-garde.
		heat = minf(heat, heat_after_blanc)
		a.heat_given = true   # la Frappe à blanc elle-même ne rechauffe pas
	else:
		Sfx.play("souffle", -10.0, 0.9 if a.heavy else 1.2)


func _attack_rect() -> Rect2:
	var a := _atk
	if a.blanc:
		return Rect2(position + Vector2(-140 + facing * 30, -120), Vector2(280, 190))
	match a.dir:
		1:
			return Rect2(position + Vector2(-34, -110), Vector2(68, 82))
		2:
			return Rect2(position + Vector2(-28, 10), Vector2(56, 72))
		3:
			var w := 96.0
			return Rect2(position + Vector2(4 if facing > 0 else -4 - w, -40), Vector2(w, 70))
	var ww := 78.0
	return Rect2(position + Vector2(4 if facing > 0 else -4 - ww, -36), Vector2(ww, 60))


func heat_tier() -> int:
	if heat >= 100.0:
		return 3
	if heat >= 67.0:
		return 2
	if heat >= 34.0:
		return 1
	return 0


func _resolve_hits() -> void:
	var a := _atk
	var rect := _attack_rect()
	var tier := heat_tier()
	var dmg := 2
	if a.heavy:
		dmg = 3 + int(round(4.0 * a.charge))
	if a.blanc:
		dmg = 14
	elif tier >= 1:
		dmg += 1
	var info := {
		"damage": dmg,
		"source_x": position.x,
		"dir": Vector2(facing, -0.3) if a.dir != 1 else Vector2(0, -1),
		"burn": tier >= 1 or a.blanc,
		"guard_break": a.blanc or tier >= 2 or (a.heavy and a.charge >= 0.99),
		"heavy": a.heavy,
		"charge": a.charge,
		"blanc": a.blanc,
	}
	var landed := false
	for target in get_tree().get_nodes_in_group("hittable"):
		if target in a.hit or not target.get_hurt_rect().intersects(rect):
			continue
		a.hit.append(target)
		var res: String = target.take_hit(info)
		if res == "none":
			continue
		landed = true
		var at: Vector2 = target.get_hurt_rect().get_center()
		at.x = lerpf(at.x, position.x, 0.4)
		if res == "guard":
			Game.inst.fx.sparks(at, 10, Color(0.95, 0.9, 0.7), 300.0)
			velocity.x = -facing * 160.0
		else:
			var col := Color(1.0, 0.6, 0.2) if tier >= 1 else Color(0.85, 0.82, 0.75)
			Game.inst.fx.sparks(at, 8 + tier * 6, col, 280.0 + tier * 80.0)
			Game.inst.fx.sparks(at, 6, Color(0.6, 0.05, 0.05), 220.0, 1200.0, 0.6)
			rage = minf(rage + (15.0 if a.blanc else 5.0), max_rage)
		if not a.blanc:
			Sfx.play("coup_lourd" if a.heavy else "coup", -2.0)
			Sfx.play("enclume", -8.0 + tier * 2.0, 1.0 + tier * 0.08)
			Game.inst.hitstop(0.09 if a.heavy else 0.05)
			Game.inst.shake(6.0 if a.heavy else 3.0)

	if a.heavy or a.blanc:
		for wall in get_tree().get_nodes_in_group("fragile"):
			if wall in a.hit or not wall.get_rect().intersects(rect):
				continue
			a.hit.append(wall)
			if wall.try_break(info):
				landed = true

	# Frappe vers le bas : rebond sur les ennemis et les pics.
	if a.dir == 2 and not a.has("pogo"):
		var pogo := landed
		for r in Game.inst.hazard_rects:
			if r.intersects(rect):
				pogo = true
		if pogo:
			a["pogo"] = true
			velocity.y = pogo_velocity
			_air_dash = true
			Sfx.play("enclume", -8.0, 1.2)
			Game.inst.fx.sparks(position + Vector2(0, 50), 8, Color(0.95, 0.9, 0.7), 250.0)
			_state_time = a.windup + a.active   # passe directement à la fin du coup

	if landed:
		a.connected = true
		if a.cadence and not a.heat_given:
			a.heat_given = true
			_add_heat(heat_on_hit * (1.5 if a.heavy else 1.0))


func _add_heat(amount: float) -> void:
	var before := heat_tier()
	heat = minf(heat + amount, 100.0)
	var after := heat_tier()
	if after > before:
		var names := ["", "Rougeoie", "Brise-garde", "À blanc : frappe !"]
		Game.inst.fx.text(position + Vector2(0, -60), names[after], Color(1.0, 0.6 + after * 0.12, 0.25), 18)


func _update_heat(delta: float) -> void:
	if _last_strike_usec < 0 or state == S.ATTACK:
		return
	var since := (Time.get_ticks_usec() - _last_strike_usec) / 1_000_000.0
	var grace := heat_grace * (1.6 if heat >= 100.0 else 1.0)
	if since > grace:
		heat = maxf(heat - heat_decay * delta, 0.0)


# =============================================================================
#  Rage, Panser, Trempe, Contre
# =============================================================================

func _try_heal() -> void:
	if rage < heal_cost or hp >= max_hp or not is_on_floor():
		Game.inst.fx.text(position + Vector2(0, -50), "Pas assez de Rage" if rage < heal_cost else "Impossible", Color(0.7, 0.7, 0.7), 14)
		return
	rage -= heal_cost   # dépensée tout de suite : un coup gâche le bandage
	_set_state(S.HEAL)
	Sfx.play("souffle", -6.0, 0.6)


func _try_quench() -> void:
	if heat <= 0.0:
		Game.inst.fx.text(position + Vector2(0, -50), "L'arme est froide", Color(0.7, 0.7, 0.7), 14)
		return
	if not _near_quench_source():
		Game.inst.fx.text(position + Vector2(0, -50), "Il faut de l'eau ou du sang", Color(0.7, 0.7, 0.7), 14)
		return
	heat = 0.0
	streak = 0
	_haste = quench_haste_time
	_set_state(S.QUENCH)
	Sfx.play("trempe")
	Game.inst.fx.sparks(position + Vector2(facing * 26, 24), 24, Color(0.85, 0.9, 0.95), 240.0, -300.0, 0.9)
	Game.inst.fx.text(position + Vector2(0, -60), "Trempe : vitesse !", Color(0.8, 0.9, 1.0), 18)


func _near_quench_source() -> bool:
	var feet := Rect2(position + Vector2(-20, 20), Vector2(40, 16))
	for r in Game.inst.water_rects:
		if feet.intersects(r):
			return true
	for n in get_tree().get_nodes_in_group("trempe"):
		if n.can_quench() and absf(n.global_position.x - position.x) < 80.0 and absf(n.global_position.y - position.y) < 70.0:
			return true
	return false


## Appelé par un ennemi au moment où son coup arrive sur Wendel.
## Renvoie "contre", "esquive" ou "touche".
func receive_attack(attacker: Node2D, damage: int) -> String:
	if state == S.DEAD:
		return "esquive"
	var from_front := signf(attacker.global_position.x - position.x) == facing
	if state == S.PARRY and _state_time <= parry_window and from_front:
		Sfx.play("contre", 0.0)
		Game.inst.hitstop(0.14)
		Game.inst.shake(8.0)
		Game.inst.fx.sparks((attacker.global_position + position) * 0.5, 30, Color(1.0, 0.95, 0.8), 450.0)
		Game.inst.fx.text(position + Vector2(0, -64), "CONTRE !", Color(1.0, 0.95, 0.8), 20)
		rage = minf(rage + 15.0, max_rage)
		_invuln = 0.3
		_set_state(S.NORMAL)
		return "contre"
	if _invuln > 0.0:
		return "esquive"
	_hurt(damage, attacker.global_position, false)
	return "touche"


func _hurt(damage: int, from: Vector2, hazard: bool) -> void:
	if _invuln > 0.0 and not hazard:
		return
	if state == S.SLIDE:
		_set_body(BODY)
	if state == S.HEAL:
		Game.inst.fx.text(position + Vector2(0, -70), "Bandage gâché", Color(0.8, 0.3, 0.3), 14)
	hp -= damage
	rage = minf(rage + 12.0, max_rage)   # plus il souffre, plus il devient dangereux
	_invuln = 1.0
	Sfx.play("blesse")
	Game.inst.hitstop(0.1)
	Game.inst.shake(9.0)
	Game.inst.fx.sparks(position, 14, Color(0.6, 0.05, 0.05), 300.0, 1200.0, 0.7)
	if hp <= 0:
		hp = 0
		Sfx.play("mort")
		Game.inst.fx.text(position + Vector2(0, -60), "Wendel tombe", Color(0.8, 0.2, 0.2), 20)
		_set_state(S.DEAD)
		velocity = Vector2(signf(position.x - from.x) * 200.0, -300.0)
		return
	_set_state(S.HURT)
	var away := signf(position.x - from.x)
	if away == 0.0:
		away = -facing
	velocity = Vector2(away * 280.0, -320.0)


# =============================================================================
#  Utilitaires
# =============================================================================

func _set_state(s: S) -> void:
	if state == S.SLIDE and s != S.SLIDE:
		_set_body(BODY)
	state = s
	_state_time = 0.0


func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0


func get_hurt_rect() -> Rect2:
	var size := _box.size
	return Rect2(position + Vector2(-size.x * 0.5, _shape.position.y - size.y * 0.5), size)


## Pour l'interface : avance (0..1) vers le prochain temps de frappe idéal.
func beat_phase() -> float:
	if _last_strike_usec < 0:
		return -1.0
	var since := (Time.get_ticks_usec() - _last_strike_usec) / 1_000_000.0
	if since > beat + 0.4:
		return -1.0
	return since / beat


func haste_left() -> float:
	return _haste


func is_dead() -> bool:
	return state == S.DEAD


# =============================================================================
#  Dessin gris
# =============================================================================

func _draw() -> void:
	var blink := _invuln > 0.0 and state != S.DASH and int(_invuln * 20.0) % 2 == 0
	var a := 0.35 if blink else 1.0
	var body_col := Color(0.82, 0.78, 0.7, a)
	var heat_col := _heat_color()
	heat_col.a = a

	if heat_tier() >= 1:
		draw_circle(Vector2(facing * 20, -10), 26.0 + heat_tier() * 8.0, Color(1.0, 0.5, 0.15, 0.08 * heat_tier()))
	if _haste > 0.0:
		draw_rect(Rect2(-BODY.x * 0.5 - facing * 12, -BODY.y * 0.5, BODY.x, BODY.y), Color(0.6, 0.8, 1.0, 0.18))

	if state == S.DEAD:
		draw_rect(Rect2(-28, 14, 56, 14), Color(0.5, 0.45, 0.4, 1.0))
		return

	var r := get_hurt_rect()
	r.position -= position
	draw_rect(r, body_col)
	# Tête et regard
	var head_y := r.position.y + 10.0
	draw_rect(Rect2(facing * 4 - 4, head_y - 4, 8, 6), Color(0.2, 0.18, 0.16, a))

	match state:
		S.HEAL:
			var k := _state_time / heal_time
			for i in 3:
				var y := -10.0 + i * 8.0
				draw_line(Vector2(-14, y), Vector2(-14 + 28 * clampf(k * 3.0 - i, 0.0, 1.0), y), Color(0.95, 0.93, 0.88), 3.0)
		S.PARRY:
			var on := _state_time <= parry_window
			draw_arc(Vector2(facing * 10, -6), 30.0, -PI * 0.5 if facing > 0 else PI * 0.5, PI * 0.5 if facing > 0 else PI * 1.5, 12,
				Color(1.0, 0.95, 0.8, 0.9 if on else 0.3), 4.0)
		S.QUENCH:
			draw_rect(Rect2(facing * 14 - 3, 0, 6, 30), Color(0.85, 0.9, 0.95, 0.7))

	_draw_hammer(heat_col)


func _heat_color() -> Color:
	var base := Color(0.55, 0.53, 0.5)
	if heat >= 100.0:
		return Color(1.0, 0.97, 0.85)
	var k := heat / 100.0
	return base.lerp(Color(1.0, 0.45, 0.1), clampf(k * 1.4, 0.0, 1.0))


func _draw_hammer(col: Color) -> void:
	var ang := 100.0
	var reach := 34.0
	if state == S.ATTACK:
		var a := _atk
		var t := _state_time
		var w: float = a.windup
		var ac: float = a.active
		var start := -120.0
		var end := 60.0
		match a.dir:
			1:
				start = 150.0
				end = 270.0
			2:
				start = -60.0
				end = 90.0
				reach = 42.0
			3:
				start = -140.0
				end = 70.0
				reach = 42.0
		if a.blanc:
			reach = 46.0
		if t < w:
			ang = lerpf(100.0, start, t / w)
		elif t < w + ac:
			ang = lerpf(start, end, (t - w) / ac)
		else:
			ang = end
			if a.dir == 2:
				ang = 90.0
	elif state == S.CHARGE:
		ang = -140.0 + sin(_state_time * 60.0) * 4.0 * _charge
		reach = 42.0
	elif state == S.DASH or state == S.SLIDE:
		ang = 170.0
	if facing < 0:
		ang = 180.0 - ang
	var shoulder := Vector2(0, -14)
	if state == S.SLIDE:
		shoulder = Vector2(0, 14)
	var dir := Vector2.from_angle(deg_to_rad(ang))
	var tip := shoulder + dir * reach
	draw_line(shoulder, tip, Color(0.45, 0.35, 0.25), 4.0)
	var head := 9.0 if state != S.CHARGE else 9.0 + _charge * 3.0
	var perp := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([
		tip + perp * head - dir * 6.0, tip + perp * head + dir * 8.0,
		tip - perp * head + dir * 8.0, tip - perp * head - dir * 6.0])
	draw_colored_polygon(pts, col)
	if state == S.ATTACK and _state_time >= _atk.windup and _state_time < _atk.windup + _atk.active:
		var r := _attack_rect()
		r.position -= position
		draw_rect(r, Color(col.r, col.g, col.b, 0.15))
