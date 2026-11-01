class_name ChevalierNoir
extends Node2D
## La première nuit dans la Lande : un homme en armure noire surgit, taille les spectres
## qui submergent Wendel, et repart sans un mot. (Une scène : il ne se combat pas.)

enum S { ARRIVE, SLASH, STAND, LEAVE }

const RUN := 520.0

var state := S.ARRIVE
var facing := 1
var _t := 0.0
var _slash_t := 0.0
var _swings := 0
var _arc := 0.0


func _ready() -> void:
	z_index = 8


func _physics_process(delta: float) -> void:
	_t += delta
	_slash_t = maxf(_slash_t - delta, 0.0)
	var p := Game.inst.player
	position.y = Game.inst.floor_below(position + Vector2(0, -80)) - 34.0
	match state:
		S.ARRIVE:
			facing = 1 if p.position.x > position.x else -1
			position.x += facing * RUN * delta
			if absf(p.position.x - position.x) < 120.0 or _t > 3.0:
				_go(S.SLASH)
		S.SLASH:
			var spirits := _spirits()
			if _slash_t <= 0.0:
				if spirits.is_empty() or _swings >= 8:
					_go(S.STAND)
				else:
					_swing(spirits)
		S.STAND:
			if _t > 1.4:
				facing = 1
				_go(S.LEAVE)
		S.LEAVE:
			position.x += facing * RUN * 0.6 * delta
			if _t > 3.5:
				queue_free()
	queue_redraw()


func _spirits() -> Array:
	return get_parent().get_children().filter(func(n): return n is Spirit and not n.dead)


## Un grand coup en arc : tous les spectres à portée se défont.
func _swing(spirits: Array) -> void:
	_swings += 1
	_slash_t = 0.32
	var target: Node2D = spirits[0]
	for s in spirits:
		if s.position.distance_to(position) < target.position.distance_to(position):
			target = s
	facing = 1 if target.position.x > position.x else -1
	# Il s'avance d'un pas vers le spectre le plus proche.
	position.x += clampf(target.position.x - position.x, -90.0, 90.0)
	Sfx.play("coup_lourd", 2.0, 0.55)
	Game.inst.shake(7.0)
	_arc = 1.0
	for s in spirits:
		if s.position.distance_to(position + Vector2(facing * 60.0, -40.0)) < 230.0:
			s._die()
			Game.inst.fx.sparks(s.position, 14, LevelDraw.C_SPIRIT, 300.0, 200.0, 0.6)


func _go(s: S) -> void:
	state = s
	_t = 0.0


func _draw() -> void:
	var dark := Color(0.08, 0.08, 0.1)
	# Une silhouette massive, toute noire ; on ne voit pas son visage.
	draw_rect(Rect2(-20, -40, 40, 54), dark)
	draw_rect(Rect2(-24, -44, 48, 14), dark)
	draw_circle(Vector2(0, -54), 13.0, dark)
	draw_rect(Rect2(-14, 14, 11, 20), dark)
	draw_rect(Rect2(3, 14, 11, 20), dark)
	# une cape déchirée
	draw_colored_polygon(PackedVector2Array([Vector2(-22, -40), Vector2(-facing * 46, 20), Vector2(-6, 10)]), Color(0.12, 0.1, 0.1))
	if _slash_t > 0.0:
		var a := _slash_t / 0.32
		draw_arc(Vector2(facing * 30, -40), 120.0, -PI * 0.5 - 0.8 if facing > 0 else PI * 0.5 - 0.8, -PI * 0.5 + 1.4 if facing > 0 else PI * 0.5 + 1.4, 16, Color(0.9, 0.9, 0.95, a * 0.8), 10.0)
	else:
		# la lame, énorme, portée sur l'épaule
		draw_line(Vector2(-6, -40), Vector2(-facing * 70, -90), Color(0.18, 0.18, 0.2), 14.0)
