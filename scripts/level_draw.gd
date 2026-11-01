class_name LevelDraw
extends Node2D
## Dessin « gris » d'une salle : blocs, eau, pics, bois, brume, cercles de sel, brasiers, corps et panneaux.
## Les blocs portent une matière (roche, bois, maçonnerie, chair, éboulis, fer) dessinée très sommairement,
## et des étiquettes discrètes disent ce que représentent les volumes : de simples indications pour la DA.

var solids: Array[Rect2] = []
var solid_mats: Array[String] = []
var outdoor := false
var hanged: Array[Vector2] = []
var labels: Array = []
var water: Array[Rect2] = []
var hazards: Array[Rect2] = []
var rests: Array = []
var mist: Array[Rect2] = []
var planks: Array[Rect2] = []
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
	if not mist.is_empty() or not rests.is_empty() or not hanged.is_empty():
		queue_redraw()


func _draw() -> void:
	var night := World.night_amount()
	if outdoor:
		# Le ciel bas de la Lande, du gris au violet ; la nuit l'assombrit par la teinte.
		var vr := get_viewport_rect()
		var room_size: Vector2 = Game.inst.room.size if is_instance_valid(Game.inst.room) else vr.size
		for i in 8:
			var band := Rect2(0, room_size.y * i / 8.0, room_size.x, room_size.y / 8.0 + 1.0)
			draw_rect(band, Color(0.26, 0.25, 0.3).lerp(Color(0.16, 0.15, 0.18), i / 8.0))
	for i in solids.size():
		_draw_block(solids[i], solid_mats[i] if i < solid_mats.size() else "roche")
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
	for r in planks:
		# Échafaudage de mine : une planche sur deux poteaux.
		draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(r.size.x, 8)), Color(0.45, 0.36, 0.27))
		draw_line(r.position + Vector2(0, 2), Vector2(r.end.x, r.position.y + 2), Color(0.6, 0.5, 0.38), 2.0)
		for px in [r.position.x + 6.0, r.end.x - 6.0]:
			draw_line(Vector2(px, r.position.y + 10), Vector2(px, r.position.y + 30), Color(0.38, 0.3, 0.23), 3.0)
	for r in mist:
		# Le jour, une brume à peine visible ; la nuit, une dalle spectrale sur laquelle on marche.
		var c := C_SPIRIT
		c.a = lerpf(0.12, 0.75, night)
		draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(r.size.x, 10)), c)
		for i in 3:
			var wx := r.position.x + fmod(_t * 18.0 + i * 37.0, r.size.x)
			draw_circle(Vector2(wx, r.position.y + 6 + sin(_t * 2.0 + i) * 3.0), 5.0, Color(c.r, c.g, c.b, c.a * 0.5))
	for h in hanged:
		# un pendu : la corde, le corps qui tourne doucement
		var sw := sin(_t * 0.8 + h.x * 0.01) * 3.0
		draw_line(h, h + Vector2(sw, 22), Color(0.55, 0.45, 0.3), 2.0)
		draw_circle(h + Vector2(sw, 28), 7.0, Color(0.42, 0.4, 0.38))
		draw_rect(Rect2(h + Vector2(sw - 8, 34), Vector2(16, 30)), Color(0.32, 0.29, 0.26))
		draw_line(h + Vector2(sw - 4, 64), h + Vector2(sw - 5, 80), Color(0.3, 0.27, 0.24), 4.0)
		draw_line(h + Vector2(sw + 4, 64), h + Vector2(sw + 5, 80), Color(0.3, 0.27, 0.24), 4.0)
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
	for lb in labels:
		draw_string(font, lb[0] + Vector2(2, 22), lb[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.78, 0.74, 0.66, 0.55))
	for h in hints:
		draw_string(font, h[0], h[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.82, 0.74, 0.75))


## Un bloc plein, selon sa matière. Tout reste sommaire : une teinte et un motif suffisent à lire le volume.
func _draw_block(r: Rect2, mat: String) -> void:
	match mat:
		"ciel":
			pass
		"bois":
			draw_rect(r, Color(0.4, 0.31, 0.22))
			var y := r.position.y + 10.0
			while y < r.end.y:
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.3, 0.23, 0.16), 2.0)
				y += 11.0
			draw_line(r.position, Vector2(r.end.x, r.position.y), Color(0.56, 0.45, 0.33), 2.0)
		"maconnerie":
			draw_rect(r, Color(0.45, 0.42, 0.37))
			var row := 0
			var y := r.position.y + 16.0
			while y < r.end.y:
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.33, 0.31, 0.28), 2.0)
				var x := r.position.x + (16.0 if row % 2 == 0 else 0.0)
				while x < r.end.x:
					draw_line(Vector2(x, y - 16.0), Vector2(x, y), Color(0.33, 0.31, 0.28), 2.0)
					x += 32.0
				y += 16.0
				row += 1
			draw_line(r.position, Vector2(r.end.x, r.position.y), Color(0.6, 0.57, 0.5), 2.0)
		"chair":
			draw_rect(r, Color(0.36, 0.17, 0.17))
			var n := int(r.size.x * r.size.y / 900.0) + 1
			for k in n:
				var px := r.position.x + _rnd(k, r.position.x) * r.size.x
				var py := r.position.y + _rnd(k, r.position.y + 7.0) * r.size.y
				draw_arc(Vector2(px, py), 9.0, 0.3 * k, 0.3 * k + 2.4, 8, Color(0.55, 0.25, 0.24), 2.0)
			draw_line(r.position, Vector2(r.end.x, r.position.y), Color(0.6, 0.32, 0.3), 2.0)
		"eboulis":
			draw_rect(r, Color(0.33, 0.32, 0.3))
			var n := int(r.size.x * r.size.y / 500.0) + 1
			for k in n:
				var px := r.position.x + _rnd(k, r.position.x + 3.0) * r.size.x
				var py := r.position.y + _rnd(k, r.position.y + 11.0) * r.size.y
				draw_circle(Vector2(px, py), 3.0 + fmod(k * 1.7, 4.0), Color(0.45, 0.43, 0.4))
			draw_line(r.position, Vector2(r.end.x, r.position.y), C_EDGE, 2.0)
		"fer":
			draw_rect(r, Color(0.26, 0.28, 0.31))
			var x := r.position.x + 8.0
			while x < r.end.x:
				draw_circle(Vector2(x, r.position.y + 6.0), 2.0, Color(0.5, 0.52, 0.55))
				draw_circle(Vector2(x, r.end.y - 6.0), 2.0, Color(0.5, 0.52, 0.55))
				x += 16.0
			draw_rect(r, Color(0.45, 0.47, 0.5), false, 2.0)
		_:
			draw_rect(r, C_BLOCK)
			draw_line(r.position, Vector2(r.end.x, r.position.y), C_EDGE, 2.0)


## Un nombre entre 0 et 1, toujours le même pour (k, graine) : les motifs ne bougent pas d'une image à l'autre.
func _rnd(k: int, seed: float) -> float:
	var v := sin(k * 12.9898 + seed * 78.233) * 43758.5453
	return v - floor(v)
