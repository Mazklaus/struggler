class_name WendelArt
extends Sprite2D
## Wendel image par image (planches produites par tools/art/art.py wendel), posé sur le Player gris.
## Le dessin gris du Player est masqué (self_modulate) ; ses collisions et coups ne changent pas.
## Animations connues : repos, course (les autres viendront : saut, chute, coups).

const DIR := "res://art/personnages/wendel/"
const BODY_H := 56.0   # hauteur du corps du Player (pieds au centre + 28)
## Échelle du jeu : 1 case = 1 m. Wendel mesure 1,95 m dessiné (cheveux compris), soit ~62 px :
## le dessin déborde un peu de sa hitbox (28 × 56 px), qui ne change pas.
const HAUTEUR_M := 1.95

var player: Player
## Attaques en poses clés (tools/art/art.py poses) : le corps vient de la planche, l'arme est une
## couche à part posée dans la main (« mains », « angles »), et une traînée d'encre fait le mouvement.
const ARME_LONGUEUR_M := 0.7
const ARME_POIGNEE := Vector2(8, 91)   # dans armes/marteau.png
var poses := {}        # nom de planche -> méta (+ "tex")
var _arme: Sprite2D
var _trainee: Node2D
var _pose := -1
var anims := {}        # nom -> {"tex", "n", "w", "h", "fps", "appui", "boucle"}
var current := ""
var _t := 0.0


static func available() -> bool:
	return FileAccess.file_exists(DIR + "repos.json")


func setup(p: Player) -> void:
	player = p
	name = "WendelArt"
	centered = false
	for a in ["repos", "course"]:
		var f := FileAccess.open(DIR + a + ".json", FileAccess.READ)
		if f == null:
			continue
		var m: Dictionary = JSON.parse_string(f.get_as_text())
		m["tex"] = load(DIR + a + ".png")
		anims[a] = m
	for a in ["marteau"]:
		var f := FileAccess.open(DIR + a + ".json", FileAccess.READ)
		if f:
			var m: Dictionary = JSON.parse_string(f.get_as_text())
			m["tex"] = load(DIR + a + ".png")
			poses[a] = m
	if not poses.is_empty() and ResourceLoader.exists(DIR + "armes/marteau.png"):
		_arme = Sprite2D.new()
		_arme.texture = load(DIR + "armes/marteau.png")
		_arme.centered = false
		_arme.offset = -ARME_POIGNEE
		_arme.visible = false
		add_child(_arme)
		_trainee = Trainee.new()
		add_child(_trainee)
	region_enabled = true
	# Planches en haute définition réduites à l'écran : mipmaps pour un trait net, sans crénelage.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_play("repos")


func show_art(on: bool) -> void:
	visible = on
	player.self_modulate.a = 0.0 if on else 1.0


func _play(a: String) -> void:
	if a == current or not anims.has(a):
		return
	current = a
	_t = 0.0
	texture = anims[a].tex


func _process(delta: float) -> void:
	if player == null or not visible:
		return
	if _attack_pose():
		return
	var moving := absf(player.velocity.x) > 30.0 and player.is_on_floor()
	_play("course" if moving and anims.has("course") else "repos")
	var m: Dictionary = anims[current]
	_t += delta
	var n: int = m.images
	var i := int(_t * float(m.fps))
	i = i % n if m.get("boucle", true) else mini(i, n - 1)
	var k: float = HAUTEUR_M * Room.TILE / float(m.taille) if m.has("taille") else float(m.get("echelle_jeu", 0.5))
	region_rect = _frame_rect(m, i)
	scale = Vector2(k * player.facing, k)
	# Le point d'appui de la planche (pieds) se pose sous les pieds du Player.
	position = Vector2(-float(m.appui[0]) * k * player.facing, BODY_H * 0.5 - float(m.appui[1]) * k)



## Pendant une frappe du Marteau : la pose selon la phase du coup (armé, impact, suite, garde),
## l'arme dans la main et la traînée. Renvoie false hors attaque.
func _attack_pose() -> bool:
	var m: Dictionary = poses.get("marteau", {})
	# Charge du coup lourd : Wendel tient la pose d'armé du coup lourd.
	var charge: bool = player.state == Player.S.CHARGE and player.weapon == Player.W.MARTEAU
	if m.is_empty() or player.weapon != Player.W.MARTEAU or not (charge or (player.state == Player.S.ATTACK and not player._atk.is_empty())):
		if _pose >= 0:
			_pose = -1
			current = ""
			_arme.visible = false
			_trainee.hide_now()
		return false
	var a: Dictionary = player._atk if not charge else {"dir": 3, "windup": 1e9, "active": 0.0, "recovery": 0.0}
	var t: float = player._state_time
	var names: Array = m.poses
	# Poses du coup selon sa direction : côté, haut, bas en l'air, lourd (dir 3).
	var dir: int = a.get("dir", 0)
	var pre := "haut_" if dir == 1 else ("bas_" if dir == 2 else ("lourd_" if dir == 3 else ""))
	if pre != "" and names.find(pre + "arme") < 0:
		pre = ""
	var nom := "garde" if pre != "bas_" else pre + "impact"
	if t < a.windup:
		nom = pre + "arme"
	elif t < a.windup + a.active:
		nom = pre + "impact"
	elif t < a.windup + a.active + a.recovery * 0.55:
		nom = "suite" if pre in ["", "lourd_"] else pre + "impact"
	var i := names.find(nom)
	if i < 0:   # pose pas encore dessinée : celle du coup de côté
		i = names.find(nom.trim_prefix(pre))
	if _pose == -1:
		current = ""
	_pose = i
	texture = m.tex
	var k := HAUTEUR_M * Room.TILE / float(m.taille)
	region_rect = _frame_rect(m, i)
	scale = Vector2(k * player.facing, k)
	position = Vector2(-float(m.appui[0]) * k * player.facing, BODY_H * 0.5 - float(m.appui[1]) * k)
	# L'arme : longueur réelle en mètres, convertie en pixels de planche.
	var px_m := float(m.taille) / HAUTEUR_M
	var ka := ARME_LONGUEUR_M * px_m / float(_arme.texture.get_width())
	_arme.visible = true
	_arme.scale = Vector2(ka, ka)
	_arme.position = Vector2(m.mains[i][0], m.mains[i][1])
	_arme.rotation = deg_to_rad(float(m.angles[i]))
	# Traînée : de la tête de l'arme à l'armé jusqu'à l'impact, en arc par-dessus.
	if t >= a.windup and not _trainee.active:
		var tete := func(j: int) -> Vector2:
			return Vector2(m.mains[j][0], m.mains[j][1]) + Vector2.from_angle(deg_to_rad(float(m.angles[j]))) * ARME_LONGUEUR_M * px_m * 0.92
		_trainee.start(tete.call(names.find(pre + "arme")), tete.call(names.find(pre + "impact")), a.get("blanc", false), float(m.taille) / 112.0)
	return true


## Arc d'encre et de braise qui suit le coup, puis s'efface (dessiné dans l'espace de la planche).
class Trainee extends Node2D:
	var active := false
	var _a := Vector2.ZERO
	var _b := Vector2.ZERO
	var _t := 0.0
	var _blanc := false
	var _u := 1.0          # taille de la planche / 112 (les mesures ci-dessous sont pour 112 px)
	const DUREE := 0.16

	func start(from: Vector2, to: Vector2, blanc: bool, u: float) -> void:
		_u = u
		active = true
		_a = from
		_b = to
		_t = 0.0
		_blanc = blanc
		show()

	func hide_now() -> void:
		active = false
		hide()

	func _process(delta: float) -> void:
		if not visible:
			return
		_t += delta
		if _t > DUREE:
			hide()
		queue_redraw()

	func _draw() -> void:
		var f := clampf(_t / DUREE, 0.0, 1.0)
		# Arc bombé vers l'avant ou vers le haut, quel que soit le sens du coup.
		var d := _b - _a
		var perp := Vector2(-d.y, d.x).normalized()
		if perp.y > 0.0 and absf(perp.x) < 0.7 or perp.x < -0.7:
			perp = -perp
		var ctrl := (_a + _b) * 0.5 + perp * d.length() * 0.45
		var n := 14
		var pts_out := PackedVector2Array()
		var pts_in := PackedVector2Array()
		for j in n + 1:
			var u := float(j) / n
			var p := _a.lerp(ctrl, u).lerp(ctrl.lerp(_b, u), u)
			var nxt := _a.lerp(ctrl, minf(u + 0.01, 1.0)).lerp(ctrl.lerp(_b, minf(u + 0.01, 1.0)), minf(u + 0.01, 1.0))
			var tan := (nxt - p).normalized() if j < n else (_b - ctrl).normalized()
			var nor := Vector2(-tan.y, tan.x)
			var w := 16.0 * _u * u * (1.0 - f * 0.6)     # fine à l'arrière, épaisse à l'impact
			pts_out.append(p + nor * w * 0.5)
			pts_in.append(p - nor * w * 0.5)
		pts_in.reverse()
		var poly := pts_out + pts_in
		var ink := Color(0.08, 0.05, 0.07, 0.85 * (1.0 - f))
		var ember := Color(1.0, 0.85, 0.6, 0.9 * (1.0 - f)) if _blanc else Color(0.95, 0.55, 0.25, 0.7 * (1.0 - f))
		draw_colored_polygon(poly, ink)
		draw_polyline(pts_out, ember, 2.0 * _u, true)


## Rectangle de l'image i dans une planche en grille (« colonnes » ; une seule ligne sinon).
func _frame_rect(m: Dictionary, i: int) -> Rect2:
	var cols := int(m.get("colonnes", m.images))
	return Rect2((i % cols) * float(m.largeur), (i / cols) * float(m.hauteur), float(m.largeur), float(m.hauteur))
