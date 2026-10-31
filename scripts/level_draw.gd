class_name LevelDraw
extends Node2D
## Dessin « gris » du niveau : blocs, eau, pics et panneaux d'aide.

var solids: Array[Rect2] = []
var water: Array[Rect2] = []
var hazards: Array[Rect2] = []
var hints: Array = []

const C_BLOCK := Color(0.36, 0.35, 0.33)
const C_EDGE := Color(0.5, 0.49, 0.46)
const C_WATER := Color(0.25, 0.42, 0.55, 0.65)
const C_SPIKE := Color(0.62, 0.6, 0.56)


func _draw() -> void:
	for r in solids:
		draw_rect(r, C_BLOCK)
		draw_line(r.position, Vector2(r.end.x, r.position.y), C_EDGE, 2.0)
	for r in water:
		draw_rect(r, C_WATER)
		draw_line(r.position + Vector2(0, 3), Vector2(r.end.x, r.position.y + 3), Color(0.6, 0.8, 0.9, 0.8), 2.0)
	for r in hazards:
		var n := int(r.size.x / 12.0)
		for i in n:
			var x0 := r.position.x + i * r.size.x / n
			var x1 := x0 + r.size.x / n
			var base := r.position.y + 6.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(x0, base), Vector2((x0 + x1) * 0.5, base - 14.0), Vector2(x1, base)]), C_SPIKE)
	var font := ThemeDB.fallback_font
	for h in hints:
		draw_string(font, h[0], h[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.82, 0.74, 0.75))
