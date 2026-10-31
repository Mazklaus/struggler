class_name Hud
extends Control
## Interface : vie, Rage, Chaleur, Cadence, ferraille, heure de la marque, nom des salles,
## écran titre, menu de repos, textes (lettres, objets) et fondu entre les salles.

var show_help := true

const HELP := [
	"Déplacer : flèches ou ZQSD (stick)",
	"Sauter : Espace (A), maintenir pour sauter plus haut",
	"Frapper : J (X), refrapper pendant l'éclair blanc",
	"Lourde : maintenir K (Y) ; Pics : bond",
	"Ruée : Maj ou L (RB)     Glissade : C (RT)",
	"Contre : I (LB)     Panser : F (B)     Trempe : E (LT)",
	"Se reposer : haut au cercle de sel ou au brasier",
	"Écran titre : R (View)     Cacher l'aide : H (Menu)",
]


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var g := Game.inst
	var font := ThemeDB.fallback_font
	var size := get_viewport_rect().size
	if g.mode == Game.M.TITLE:
		_draw_title(font, size)
		return
	var p := g.player
	if not is_instance_valid(p):
		return
	_draw_play(p, font, size)
	_draw_clock(font, size)
	if is_instance_valid(g.boss) and g.boss.hp > 0:
		var bw := 520.0
		var bx := size.x * 0.5 - bw * 0.5
		var by := size.y - 40.0
		_center_text(font, Vector2(size.x * 0.5, by - 10), g.boss.NAME, 16, Color(0.92, 0.88, 0.8))
		draw_rect(Rect2(bx, by, bw, 10), Color(0.15, 0.13, 0.12))
		draw_rect(Rect2(bx, by, bw * g.boss.hp / g.boss.max_hp, 10), Color(0.7, 0.14, 0.12))
	if g.banner_time > 0.0:
		var a := clampf(g.banner_time, 0.0, 1.0)
		_center_text(font, Vector2(size.x * 0.5, size.y * 0.3), g.banner, 28, Color(0.95, 0.92, 0.85, a))
	if g.mode == Game.M.REST:
		_draw_rest(font, size)
	elif g.mode == Game.M.TEXT:
		_draw_text_panel(font, size)
	if g.fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, g.fade))


func _center_text(font: Font, at: Vector2, msg: String, fsize: int, col: Color) -> void:
	var w := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	draw_string_outline(font, at - Vector2(w * 0.5, 0), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 5, Color(0, 0, 0, col.a))
	draw_string(font, at - Vector2(w * 0.5, 0), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _draw_title(font: Font, size: Vector2) -> void:
	var g := Game.inst
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.075, 0.07))
	_center_text(font, Vector2(size.x * 0.5, size.y * 0.32), "STRUGGLER", 64, Color(0.92, 0.88, 0.8))
	_center_text(font, Vector2(size.x * 0.5, size.y * 0.32 + 40), "tranche verticale, blocs gris", 16, Color(0.6, 0.57, 0.52))
	for i in g.title_items.size():
		var sel := i == g.title_index
		var col := Color(1.0, 0.75, 0.45) if sel else Color(0.75, 0.72, 0.66)
		var label: String = ("> %s <" if sel else "%s") % g.title_items[i][1]
		_center_text(font, Vector2(size.x * 0.5, size.y * 0.58 + i * 38), label, 22, col)
	_center_text(font, Vector2(size.x * 0.5, size.y - 40), "haut / bas pour choisir, Espace ou J (A ou X) pour valider", 14, Color(0.55, 0.52, 0.48))


func _draw_clock(font: Font, size: Vector2) -> void:
	# En haut au centre : un arc jour/nuit, et le temps avant le prochain changement.
	var c := Vector2(size.x * 0.5, 44)
	var night := World.is_night()
	var total := World.day_length + World.night_length
	draw_arc(c, 18.0, 0.0, TAU, 32, Color(0.3, 0.28, 0.26), 4.0)
	var start := -PI * 0.5
	draw_arc(c, 18.0, start, start + TAU * World.day_length / total, 32, Color(0.9, 0.8, 0.55, 0.6), 4.0)
	draw_arc(c, 18.0, start + TAU * World.day_length / total, start + TAU, 32, Color(0.45, 0.5, 0.85, 0.6), 4.0)
	var ang := start + TAU * World.clock / total
	draw_circle(c + Vector2.from_angle(ang) * 18.0, 6.0, Color(0.55, 0.65, 1.0) if night else Color(1.0, 0.85, 0.5))
	var left := int(World.time_left())
	var msg := ("Nuit : aube dans %d:%02d" if night else "Jour : nuit dans %d:%02d") % [left / 60, left % 60]
	_center_text(font, c + Vector2(0, 40), msg, 13, Color(0.85, 0.82, 0.75))


func _draw_rest(font: Font, size: Vector2) -> void:
	var g := Game.inst
	var shown := g.menu_items.size() - 1
	var kind: String = g.menu_items[-1][0]
	var w := 420.0
	var h := 90.0 + shown * 34.0
	var r := Rect2(size.x * 0.5 - w * 0.5, size.y * 0.5 - h * 0.5, w, h)
	draw_rect(r, Color(0.05, 0.05, 0.05, 0.85))
	draw_rect(r, Color(0.9, 0.88, 0.82, 0.6), false, 2.0)
	var title := "Cercle de sel" if kind == "S" else "Brasier"
	_center_text(font, Vector2(size.x * 0.5, r.position.y + 34), title, 22, Color(0.95, 0.92, 0.85))
	for i in shown:
		var sel := i == g.menu_index
		var col := Color(1.0, 0.75, 0.45) if sel else Color(0.8, 0.77, 0.7)
		var label: String = ("> %s" if sel else "  %s") % g.menu_items[i][1]
		draw_string(font, Vector2(r.position.x + 40, r.position.y + 72 + i * 34), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
	var note := "Les esprits n'entrent pas dans le sel." if kind == "S" else "Le feu ne repousse pas les esprits."
	_center_text(font, Vector2(size.x * 0.5, r.end.y + 24), note, 13, Color(0.7, 0.68, 0.62))


func _draw_text_panel(font: Font, size: Vector2) -> void:
	var g := Game.inst
	var lines := g.text_body.split("\n")
	var w := 640.0
	var h := 110.0 + lines.size() * 24.0
	var r := Rect2(size.x * 0.5 - w * 0.5, size.y * 0.5 - h * 0.5, w, h)
	draw_rect(r, Color(0.93, 0.9, 0.82, 0.96))
	draw_rect(r.grow(-6), Color(0.3, 0.25, 0.2, 0.8), false, 2.0)
	_center_text(font, Vector2(size.x * 0.5, r.position.y + 42), g.text_title, 22, Color(0.18, 0.15, 0.12))
	for i in lines.size():
		draw_string(font, Vector2(r.position.x + 44, r.position.y + 80 + i * 24), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.15, 0.13, 0.11))
	draw_string(font, Vector2(r.end.x - 150, r.end.y - 16), "Espace / A : fermer", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.4, 0.35, 0.3))


func _draw_play(p: Player, font: Font, size: Vector2) -> void:
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
	draw_string(font, Vector2(x0 + rw + 90, ry + 11), "Ferraille %d" % World.scrap, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.72, 0.68))

	draw_string(font, Vector2(x0, ry + 40), p.weapon_name(p.weapon), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.92, 0.85))
	var hy := ry + 48
	if p.weapon == Player.W.MARTEAU and not World.has("lourde"):
		draw_string(font, Vector2(x0, hy + 12), "Coups légers seulement. Le marteau de Gerold est à la forge.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.68, 0.62))
	elif p.weapon == Player.W.PICS:
		draw_string(font, Vector2(x0, hy + 12), "L'Entaille : 5 coups sur la même cible la font saigner", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.5, 0.45))
	else:
		# Chaleur : trois paliers.
		draw_rect(Rect2(x0, hy, rw, 12), Color(0.15, 0.13, 0.12))
		var hc := Color(1.0, 0.45, 0.1).lerp(Color(1.0, 0.97, 0.85), clampf((p.heat - 67.0) / 33.0, 0.0, 1.0))
		draw_rect(Rect2(x0, hy, rw * p.heat / 100.0, 12), hc)
		for k in [34.0, 67.0]:
			draw_line(Vector2(x0 + rw * k / 100.0, hy), Vector2(x0 + rw * k / 100.0, hy + 12), Color(0.9, 0.85, 0.8, 0.6), 2.0)
		var tiers := ["froide", "rougeoie", "brise-garde", "À BLANC"]
		draw_string(font, Vector2(x0 + rw + 10, hy + 11), "Chaleur : %s" % tiers[p.heat_tier()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, hc)
		if p.haste_left() > 0.0:
			draw_string(font, Vector2(x0, hy + 30), "Trempe : vitesse %.1f s" % p.haste_left(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.85, 1.0))

		# Cadence : l'anneau se referme pendant le coup ; il s'allume en blanc pendant l'éclair.
		var center := Vector2(size.x * 0.5, size.y - 70)
		var target_r := 18.0
		draw_arc(center, target_r, 0, TAU, 32, Color(0.9, 0.85, 0.75, 0.5), 2.0)
		var prog := p.swing_progress()
		if prog >= 0.0:
			draw_arc(center, target_r + (1.0 - prog) * 50.0, 0, TAU, 40, Color(0.9, 0.85, 0.75, 0.8), 2.0)
		var win := p.window_left()
		if win > 0.0:
			draw_circle(center, target_r + 4.0, Color(1, 1, 1, 0.3 + 0.6 * win))
			draw_arc(center, target_r + 10.0, -PI * 0.5, -PI * 0.5 + TAU * win, 32, Color(1, 1, 1, 0.9), 3.0)
		var judge_age := Time.get_ticks_usec() / 1_000_000.0 - p.judgment_time
		if p.last_judgment != "" and judge_age < 0.6:
			var msg: String = p.last_judgment
			var w := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			var col := Color(1.0, 0.7, 0.3, 1.0 - judge_age / 0.6)
			draw_string(font, center + Vector2(-w * 0.5, -40), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
		if p.streak >= 2:
			draw_string(font, center + Vector2(34, 6), "x%d" % p.streak, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.7, 0.3))

	if show_help:
		# En haut à droite, pour ne rien cacher du sol.
		var hx0 := size.x - 416.0
		var hy0 := 36.0
		draw_rect(Rect2(hx0 - 8, hy0 - 18, 400, HELP.size() * 18.0 + 14), Color(0, 0, 0, 0.35))
		for i in HELP.size():
			draw_string(font, Vector2(hx0, hy0 + i * 18.0), HELP[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.88, 0.85, 0.78))
