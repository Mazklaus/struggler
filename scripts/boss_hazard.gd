class_name BossHazard
extends Node2D
## Dangers laissés par les boss : onde qui court au sol, lanterne lancée, flaque de feu,
## nœud coulant qui tombe des branches (une ombre prévient), pendu qui se détache.

var kind := "onde"         # "onde", "lanterne", "feu"
var velocity := Vector2.ZERO
var life := 2.5
var delay := 0.0           # nœud coulant : temps d'avertissement avant qu'il tombe
var _hit := false
var _t := 0.0

const SIZES := {"onde": Vector2(26, 34), "lanterne": Vector2(18, 22), "feu": Vector2(96, 18),
	"noeud": Vector2(34, 240), "pendu": Vector2(30, 50)}


func _ready() -> void:
	z_index = 7


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	match kind:
		"onde":
			position.x += velocity.x * delta
			if _in_wall():
				life = 0.0
		"lanterne":
			velocity.y += 1500.0 * delta
			position += velocity * delta
			if velocity.y > 0.0 and position.y >= Game.inst.floor_below(position - Vector2(0, 20)) - 10.0:
				var f := BossHazard.new()
				f.kind = "feu"
				f.life = 2.6
				f.position = Vector2(position.x, Game.inst.floor_below(position - Vector2(0, 20)) - 9.0)
				get_parent().add_child(f)
				Sfx.play("trempe", -6.0, 0.6)
				Game.inst.fx.sparks(position, 16, Color(1.0, 0.55, 0.15), 260.0, 700.0, 0.6)
				life = 0.0
		"noeud":
			delay -= delta
		"pendu":
			velocity.y += 1500.0 * delta
			position += velocity * delta
			var fy := Game.inst.floor_below(position - Vector2(0, 30))
			if velocity.y > 0.0 and position.y + 25.0 >= fy:
				Sfx.play("coup_lourd", -6.0, 0.8)
				Game.inst.fx.sparks(Vector2(position.x, fy), 12, Color(0.5, 0.45, 0.4), 260.0, 900.0, 0.5)
				Game.inst.add_blood(Vector2(position.x, fy))
				life = 0.0
	var p := Game.inst.player
	var armed := kind != "noeud" or delay <= 0.0
	if armed and not _hit and is_instance_valid(p) and not p.is_dead() and rect().intersects(p.get_hurt_rect()):
		var res: String = p.receive_attack(self, 1)
		if res != "esquive":
			_hit = kind != "feu"   # le feu brûle encore après l'invincibilité
	if life <= 0.0:
		queue_free()
	queue_redraw()


func rect() -> Rect2:
	var s: Vector2 = SIZES[kind]
	return Rect2(position - s * 0.5, s)


func _in_wall() -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = global_position + Vector2(signf(velocity.x) * 14.0, 0)
	q.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()


func _draw() -> void:
	var r := rect()
	r.position -= position
	match kind:
		"onde":
			var c := Color(0.55, 0.45, 0.4, 0.9)
			draw_colored_polygon(PackedVector2Array([
				Vector2(r.position.x, r.end.y), Vector2(0, r.position.y + sin(_t * 30.0) * 4.0),
				Vector2(r.end.x, r.end.y)]), c)
		"lanterne":
			draw_rect(r, Color(0.35, 0.3, 0.25))
			draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.6, 0.2))
		"noeud":
			if delay > 0.0:
				# l'ombre du nœud au sol, de plus en plus nette
				var a := clampf(1.0 - delay, 0.15, 0.8)
				draw_set_transform(Vector2(0, r.end.y), 0.0, Vector2(1.0, 0.25))
				draw_circle(Vector2.ZERO, 20.0, Color(0, 0, 0, a))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				draw_line(Vector2(0, r.position.y - 400.0), Vector2(0, r.end.y - 20.0), Color(0.55, 0.45, 0.3), 3.0)
				draw_arc(Vector2(0, r.end.y - 10.0), 12.0, 0.0, TAU, 12, Color(0.55, 0.45, 0.3), 3.0)
		"pendu":
			draw_line(Vector2(0, r.position.y - 30.0), Vector2(0, r.position.y), Color(0.55, 0.45, 0.3), 2.0)
			draw_circle(Vector2(0, r.position.y + 8.0), 8.0, Color(0.5, 0.46, 0.42))
			draw_rect(Rect2(-9, r.position.y + 16.0, 18, 34), Color(0.36, 0.32, 0.28))
		"feu":
			var a := clampf(life, 0.0, 1.0)
			for i in 6:
				var h := 14.0 + 10.0 * sin(_t * 11.0 + i * 1.3)
				var fx := r.position.x + 8.0 + i * 16.0
				draw_colored_polygon(PackedVector2Array([
					Vector2(fx - 7, r.end.y), Vector2(fx, r.end.y - h), Vector2(fx + 7, r.end.y)]),
					Color(1.0, 0.5 + 0.06 * i, 0.15, 0.85 * a))
