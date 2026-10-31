class_name LevelDraw
extends Node2D
## Dessin « gris » d'une salle : blocs, eau, pics, brume, cercles de sel, brasiers, corps et panneaux.

var solids: Array[Rect2] = []
var water: Array[Rect2] = []
var hazards: Array[Rect2] = []
var rests: Array = []
var mist: Array[Rect2] = []
var corpses: Array[Vector2] = []
var wells: Array[Rect2] = []
var hints: Array = []

const C_BLOCK := Color(0.36, 0.35, 0.33)
const C_EDGE := Color(0.5, 0.49, 0.46)
const C_WATER := Color(0.25, 0.42, 0.55, 0.65)
const C_SPIKE := Color(0.62, 0.6, 0.56)
const C_SPIRIT := Color(0.45, 0.95, 0.85)   # vert-bleu : la couleur réservée aux esprits

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if not mist.is_empty() or not rests.is_empty():
		queue_redraw()


func _draw() -> void:
	var night := World.night_amount()
	for r in solids:
		draw_rect(r, C_BLOCK)
		draw_line(r.position, Vector2(r.end.x, r.position.y), C_EDGE, 2.0)
	for r in wells:
		draw_rect(r, Color(0.28, 0.26, 0.25))
		for i in int(r.size.x / 16.0):
			draw_line(Vector2(r.position.x + i * 16 + 8, r.position.y + 2), Vector2(r.position.x + i * 16 + 8, r.end.y - 2), Color(0.5, 0.45, 0.4), 3.0)
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
	for r in mist:
		# Le jour, une brume à peine visible ; la nuit, une dalle spectrale sur laquelle on marche.
		var c := C_SPIRIT
		c.a = lerpf(0.12, 0.75, night)
		draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(r.size.x, 10)), c)
		for i in 3:
			var wx := r.position.x + fmod(_t * 18.0 + i * 37.0, r.size.x)
			draw_circle(Vector2(wx, r.position.y + 6 + sin(_t * 2.0 + i) * 3.0), 5.0, Color(c.r, c.g, c.b, c.a * 0.5))
	for c in corpses:
		draw_rect(Rect2(c + Vector2(-16, -8), Vector2(32, 8)), Color(0.4, 0.36, 0.33))
		draw_circle(c + Vector2(-12, -9), 5.0, Color(0.45, 0.4, 0.36))
	for r in rests:
		var c := Vector2(r.rect.get_center().x, r.rect.end.y - 2.0)
		if r.kind == "S":
			# Cercle de sel posé au sol.
			draw_set_transform(c, 0.0, Vector2(1.0, 0.25))
			draw_arc(Vector2.ZERO, 40.0, 0.0, TAU, 32, Color(0.95, 0.95, 0.9, 0.9), 6.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_line(c + Vector2(0, -6), c + Vector2(0, -40), Color(0.95, 0.95, 0.9, 0.5), 2.0)
		else:
			# Brasier : une vasque de fer et des flammes orange.
			draw_rect(Rect2(c + Vector2(-14, -10), Vector2(28, 10)), Color(0.3, 0.28, 0.26))
			for i in 4:
				var h := 14.0 + 8.0 * sin(_t * 9.0 + i * 1.7)
				var fx := c.x - 9.0 + i * 6.0
				draw_colored_polygon(PackedVector2Array([
					Vector2(fx - 4, c.y - 10), Vector2(fx, c.y - 10 - h), Vector2(fx + 4, c.y - 10)]),
					Color(1.0, 0.55 + 0.1 * i, 0.15, 0.85))
	var font := ThemeDB.fallback_font
	for h in hints:
		draw_string(font, h[0], h[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.82, 0.74, 0.75))
