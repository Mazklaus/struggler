class_name Fx
extends Node2D
## Étincelles, gouttes et textes flottants, tous dessinés en un seul passage.

var _parts: Array = []   # [pos, vel, life, max_life, color, gravity]
var _texts: Array = []   # [pos, text, life, color, size]


func sparks(pos: Vector2, count: int, color: Color, speed := 320.0, gravity := 900.0, life := 0.45) -> void:
	for i in count:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * speed * randf_range(0.3, 1.0)
		v.y -= speed * 0.3
		var l := life * randf_range(0.5, 1.0)
		_parts.append([pos, v, l, l, color, gravity])


func text(pos: Vector2, msg: String, color := Color.WHITE, size := 16) -> void:
	_texts.append([pos, msg, 0.9, color, size])


func _process(delta: float) -> void:
	for p in _parts:
		p[1].y += p[5] * delta
		p[0] += p[1] * delta
		p[2] -= delta
	_parts = _parts.filter(func(p): return p[2] > 0.0)
	for t in _texts:
		t[0].y -= 40.0 * delta
		t[2] -= delta
	_texts = _texts.filter(func(t): return t[2] > 0.0)
	queue_redraw()


func _draw() -> void:
	for p in _parts:
		var c: Color = p[4]
		c.a = clampf(p[2] / p[3], 0.0, 1.0)
		draw_line(p[0], p[0] - p[1] * 0.03, c, 2.0)
	var font := ThemeDB.fallback_font
	for t in _texts:
		var c: Color = t[3]
		c.a = clampf(t[2] * 2.0, 0.0, 1.0)
		var w := font.get_string_size(t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, t[4]).x
		draw_string_outline(font, t[0] - Vector2(w * 0.5, 0), t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, t[4], 4, Color(0, 0, 0, c.a))
		draw_string(font, t[0] - Vector2(w * 0.5, 0), t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, t[4], c)
