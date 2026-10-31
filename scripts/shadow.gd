class_name MarkedShadow
extends Enemy
## L'ombre de marqué : un spectre à l'image de Wendel, qui garde la ferraille perdue à sa mort.
## La vaincre rend la ferraille. Mourir avant de la reprendre la perd pour de bon.

enum S { WAIT, WALK, WINDUP, SLASH, RECOVER }

var amount := 0
var state := S.WAIT
var _t := 0.0
var _hit_done := false

const GRAVITY := 1900.0


func _ready() -> void:
	max_hp = 10
	scrap_drop = 0
	contact_damage = 1
	body_size = Vector2(28, 56)
	super._ready()
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = body_size
	shape.shape = box
	add_child(shape)


func _physics_process(delta: float) -> void:
	_t += delta
	_tick_status(delta)
	if dead:
		return
	velocity.y = minf(velocity.y + GRAVITY * delta, 900.0)
	var p := Game.inst.player
	var to_p := p.position - position
	match state:
		S.WAIT:
			velocity.x = 0.0
			if absf(to_p.x) < 300.0 and absf(to_p.y) < 120.0:
				_go(S.WALK)
		S.WALK:
			facing = 1 if to_p.x > 0.0 else -1
			velocity.x = facing * 120.0 if absf(to_p.x) > 60.0 else 0.0
			if absf(to_p.x) < 90.0 and absf(to_p.y) < 60.0 and _t > 0.4:
				_go(S.WINDUP)
		S.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
			if _t >= 0.45:
				_hit_done = false
				velocity.x = facing * 260.0
				_go(S.SLASH)
		S.SLASH:
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
			if not _hit_done:
				var reach := Rect2(position + Vector2(4 if facing > 0 else -74, -30), Vector2(70, 48))
				if reach.intersects(p.get_hurt_rect()):
					_hit_done = true
					p.receive_attack(self, 1)
			if _t >= 0.15:
				_go(S.RECOVER)
		S.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
			if _t >= 0.7:
				_go(S.WALK)
	move_and_slide()
	queue_redraw()


func take_hit(info: Dictionary) -> String:
	if not _apply_hit(info):
		return "none"
	if not dead and state != S.SLASH:
		velocity.x = info.dir.x * 160.0
	return "hit"


func _go(s: S) -> void:
	state = s
	_t = 0.0


func _on_death() -> void:
	World.scrap += amount
	World.shadow = {}
	Sfx.play("glas", -6.0, 1.3)
	Game.inst.fx.sparks(position, 30, Color(0.2, 0.18, 0.2), 300.0, -100.0, 1.0)
	Game.inst.fx.text(position + Vector2(0, -60), "Ferraille reprise (+%d)" % amount, Color(0.85, 0.8, 0.7), 18)
	queue_free()


func _draw() -> void:
	var col := _body_color(Color(0.1, 0.09, 0.12, 0.85))
	draw_rect(Rect2(-body_size * 0.5, body_size), col)
	# La marque au cou, rouge.
	draw_circle(Vector2(0, -body_size.y * 0.5 + 16), 4.0, Color(0.85, 0.1, 0.1))
	draw_rect(Rect2(facing * 4 - 4, -body_size.y * 0.5 + 6, 8, 6), Color(0.85, 0.85, 0.9, 0.7))
	if state == S.WINDUP and int(_t * 20.0) % 2 == 0:
		draw_rect(Rect2(-body_size.x * 0.5 - 3, -body_size.y * 0.5 - 3, body_size.x + 6, body_size.y + 6), Color(1.0, 0.25, 0.2, 0.9), false, 3.0)
	if state == S.SLASH:
		draw_rect(Rect2(Vector2(4 if facing > 0 else -74, -30), Vector2(70, 48)), Color(0.3, 0.25, 0.35, 0.4))
	_draw_wounds(-body_size.y * 0.5)
	var w := 36.0
	draw_rect(Rect2(-w * 0.5, -body_size.y * 0.5 - 18, w, 4), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(-w * 0.5, -body_size.y * 0.5 - 18, w * hp / max_hp, 4), Color(0.75, 0.15, 0.15))
	draw_string(ThemeDB.fallback_font, Vector2(-30, -body_size.y * 0.5 - 24), "%d ferraille" % amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.75, 0.7))
