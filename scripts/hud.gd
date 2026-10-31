class_name Hud
extends Control
## Interface du prototype : vie, Rage, Chaleur, battement de la Cadence et aide.

var show_help := true

const HELP := [
	"Déplacer : flèches ou ZQSD (stick)",
	"Sauter : Espace (A), maintenir pour sauter plus haut",
	"Frapper : J (X), avec haut ou bas (en l'air)",
	"Attaque lourde : maintenir K (Y), relâcher",
	"Ruée : Maj ou L (RB)     Glissade : C (RT)",
	"Contre : I (LB)     Panser : F (B)     Trempe : E (LT)",
	"Recommencer : R     Cacher l'aide : H",
]


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var p := Game.inst.player
	if not is_instance_valid(p):
		return
	var font := ThemeDB.fallback_font
	var size := get_viewport_rect().size
	var x0 := 24.0
	var y0 := 24.0

	# Vie : un losange par point de vie.
	for i in p.max_hp:
		var c := Vector2(x0 + 12 + i * 28, y0 + 12)
		var pts := PackedVector2Array([c + Vector2(0, -11), c + Vector2(10, 0), c + Vector2(0, 11), c + Vector2(-10, 0)])
		draw_colored_polygon(pts, Color(0.92, 0.9, 0.84) if i < p.hp else Color(0.25, 0.24, 0.22))

	# Rage : barre rouge sombre, repères tous les 33 (un pansement).
	var ry := y0 + 34
	var rw := 220.0
	draw_rect(Rect2(x0, ry, rw, 12), Color(0.15, 0.13, 0.12))
	draw_rect(Rect2(x0, ry, rw * p.rage / p.max_rage, 12), Color(0.6, 0.12, 0.1))
	for k in [p.heal_cost, p.heal_cost * 2.0, p.heal_cost * 3.0]:
		if k < p.max_rage:
			var mx: float = x0 + rw * k / p.max_rage
			draw_line(Vector2(mx, ry), Vector2(mx, ry + 12), Color(0.9, 0.85, 0.8, 0.6), 2.0)
	draw_string(font, Vector2(x0 + rw + 10, ry + 11), "Rage %d" % int(p.rage), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.8, 0.75))

	# Chaleur : trois paliers.
	var hy := ry + 22
	draw_rect(Rect2(x0, hy, rw, 12), Color(0.15, 0.13, 0.12))
	var hc := Color(1.0, 0.45, 0.1).lerp(Color(1.0, 0.97, 0.85), clampf((p.heat - 67.0) / 33.0, 0.0, 1.0))
	draw_rect(Rect2(x0, hy, rw * p.heat / 100.0, 12), hc)
	for k in [34.0, 67.0]:
		draw_line(Vector2(x0 + rw * k / 100.0, hy), Vector2(x0 + rw * k / 100.0, hy + 12), Color(0.9, 0.85, 0.8, 0.6), 2.0)
	var tiers := ["froide", "rougeoie", "brise-garde", "À BLANC"]
	draw_string(font, Vector2(x0 + rw + 10, hy + 11), "Chaleur : %s" % tiers[p.heat_tier()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, hc)
	if p.haste_left() > 0.0:
		draw_string(font, Vector2(x0, hy + 30), "Trempe : vitesse %.1f s" % p.haste_left(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.85, 1.0))

	# Battement : un anneau se resserre vers le cercle cible au moment idéal.
	var center := Vector2(size.x * 0.5, size.y - 70)
	var target_r := 18.0
	draw_arc(center, target_r, 0, TAU, 32, Color(0.9, 0.85, 0.75, 0.5), 2.0)
	var phase := p.beat_phase()
	if phase >= 0.0:
		var tol := p.tolerance / p.beat
		var ok := absf(phase - 1.0) <= tol
		var r := target_r + maxf(1.0 - phase, -0.4) * 60.0
		if r > 2.0:
			draw_arc(center, r, 0, TAU, 40, Color(1.0, 0.6, 0.2) if ok else Color(0.9, 0.85, 0.75, 0.8), 3.0 if ok else 2.0)
		if ok:
			draw_circle(center, target_r - 4.0, Color(1.0, 0.6, 0.2, 0.5))
	var judge_age := Time.get_ticks_usec() / 1_000_000.0 - p.judgment_time
	if p.last_judgment != "" and judge_age < 0.8:
		var msg: String = p.last_judgment
		var w := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var col := Color(1.0, 0.7, 0.3) if msg in ["En cadence", "Parfait"] else Color(0.65, 0.65, 0.7)
		col.a = 1.0 - judge_age / 0.8
		draw_string(font, center + Vector2(-w * 0.5, -32), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
	if p.streak >= 2:
		draw_string(font, center + Vector2(28, 6), "x%d" % p.streak, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.7, 0.3))

	if show_help:
		var hy0 := size.y - 20.0 - HELP.size() * 18.0
		draw_rect(Rect2(16, hy0 - 18, 400, HELP.size() * 18.0 + 14), Color(0, 0, 0, 0.35))
		for i in HELP.size():
			draw_string(font, Vector2(24, hy0 + i * 18.0), HELP[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.88, 0.85, 0.78))
