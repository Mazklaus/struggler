class_name Npc
extends Node2D
## Un personnage à qui parler (haut, à côté de lui). Ce qu'il dit dépend de l'avancée :
## voir Dialogues.

var id := ""
var _t := 0.0
var _near := false

const LOOKS := {
	"corvin": {"h": 60.0, "body": Color(0.62, 0.6, 0.56), "head": Color(0.8, 0.74, 0.66)},
	"berger": {"h": 40.0, "body": Color(0.5, 0.42, 0.32), "head": Color(0.82, 0.72, 0.6)},
	"paysan": {"h": 54.0, "body": Color(0.45, 0.4, 0.34), "head": Color(0.78, 0.68, 0.58)},
}


func _ready() -> void:
	z_index = 3


func _process(delta: float) -> void:
	_t += delta
	var p := Game.inst.player
	_near = is_instance_valid(p) and talk_rect().intersects(p.get_hurt_rect())
	queue_redraw()


func talk_rect() -> Rect2:
	return Rect2(position + Vector2(-48, -70), Vector2(96, 76))


func _draw() -> void:
	var look: Dictionary = LOOKS.get(id, LOOKS["paysan"])
	var h: float = look.h
	draw_rect(Rect2(-12, -h, 24, h - 12), look.body)
	draw_rect(Rect2(-9, -12, 7, 12), look.body.darkened(0.3))
	draw_rect(Rect2(2, -12, 7, 12), look.body.darkened(0.3))
	draw_circle(Vector2(0, -h - 9 + sin(_t * 1.5)), 10.0, look.head)
	if id == "corvin":
		# Corvin le Salé : un manteau blanchi de sel, un bâton, la marque au cou.
		draw_line(Vector2(18, -h - 6), Vector2(18, 0), Color(0.45, 0.36, 0.27), 4.0)
		for i in 5:
			draw_circle(Vector2(-10 + i * 5, -h + 18 + (i % 2) * 6), 2.0, Color(0.95, 0.95, 0.9))
		draw_circle(Vector2(0, -h + 2), 3.0, Color(0.7, 0.1, 0.1))
	if _near:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-34, -h - 30), "haut : parler", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.92, 0.85, 0.85))
