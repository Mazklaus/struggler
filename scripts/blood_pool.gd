class_name BloodPool
extends Node2D
## Flaque de sang laissée par un ennemi : on peut y tremper l'arme un moment.

var life := 12.0


func _ready() -> void:
	add_to_group("trempe")
	position.y = Game.inst.floor_below(position) - 2.0


func can_quench() -> bool:
	return life > 0.0


func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var a := clampf(life / 3.0, 0.0, 1.0)
	draw_rect(Rect2(-38, -2, 76, 5), Color(0.5, 0.05, 0.05, 0.85 * a))
