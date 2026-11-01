class_name WendelArt
extends Sprite2D
## Wendel image par image (planches produites par tools/art/art.py wendel), posé sur le Player gris.
## Le dessin gris du Player est masqué (self_modulate) ; ses collisions et coups ne changent pas.
## Animations connues : repos, course (les autres viendront : saut, chute, coups).

const DIR := "res://art/personnages/wendel/"
const BODY_H := 56.0   # hauteur du corps du Player (pieds au centre + 28)

var player: Player
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
	region_enabled = true
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
	var moving := absf(player.velocity.x) > 30.0 and player.is_on_floor()
	_play("course" if moving and anims.has("course") else "repos")
	var m: Dictionary = anims[current]
	_t += delta
	var n: int = m.images
	var i := int(_t * float(m.fps))
	i = i % n if m.get("boucle", true) else mini(i, n - 1)
	var k: float = m.get("echelle_jeu", 0.5)
	region_rect = Rect2(i * float(m.largeur), 0, float(m.largeur), float(m.hauteur))
	scale = Vector2(k * player.facing, k)
	# Le point d'appui de la planche (pieds) se pose sous les pieds du Player.
	position = Vector2(-float(m.appui[0]) * k * player.facing, BODY_H * 0.5 - float(m.appui[1]) * k)
