class_name EchelleDebug
extends Node2D
## Calque de contrôle d'échelle (F3, DA seulement) : 1 case = 1 m.
## Grille fine par mètre, forte tous les 5 m ; hitbox de tous les corps ; à côté de chaque décor,
## une silhouette d'homme de 1,80 m et la hauteur du décor en mètres.

const HOMME := Vector2(0.55, 1.8)   # m

var room: Room


func _ready() -> void:
	z_index = 100
	top_level = false


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	if room == null:
		return
	var t := float(Room.TILE)
	var font := ThemeDB.fallback_font
	var w := int(room.size.x / t)
	var h := int(room.size.y / t)
	for x in w + 1:
		var c := Color(1, 1, 1, 0.35 if x % 5 == 0 else 0.1)
		draw_line(Vector2(x * t, 0), Vector2(x * t, room.size.y), c, 1.0)
	for y in h + 1:
		var c := Color(1, 1, 1, 0.35 if y % 5 == 0 else 0.1)
		draw_line(Vector2(0, y * t), Vector2(room.size.x, y * t), c, 1.0)
	for x in range(0, w, 5):
		for y in range(0, h, 5):
			draw_string(font, Vector2(x * t + 2, y * t + 11), "x %d m · y %d m" % [x, y], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.5))
	# Hitbox de tous les corps (Wendel, ennemis), en coordonnées de la salle.
	for b in get_tree().root.find_children("*", "CharacterBody2D", true, false):
		for cs in (b as Node).find_children("*", "CollisionShape2D", false, false):
			var sh = (cs as CollisionShape2D).shape
			if sh is RectangleShape2D:
				var at: Vector2 = to_local((cs as Node2D).global_position)
				var sz: Vector2 = (sh as RectangleShape2D).size
				draw_rect(Rect2(at - sz * 0.5, sz), Color(0.3, 1, 0.4, 0.9), false, 1.5)
				draw_string(font, at + Vector2(-sz.x * 0.5, -sz.y * 0.5 - 3), "%.2f m" % (sz.y / t), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.3, 1, 0.4))
	# Décors : silhouette de référence et hauteur réelle.
	for sp in room.find_children("*", "Sprite2D", true, false):
		if not (sp as Node).has_meta("decor_m"):
			continue
		var p: Vector2 = to_local((sp as Node2D).global_position)
		var hw := absf((sp as Sprite2D).texture.get_width() * (sp as Node2D).scale.x) * 0.5
		var r := Rect2(p + Vector2(-hw - HOMME.x * t - 4, -HOMME.y * t), HOMME * t)
		draw_rect(r, Color(1, 0.8, 0.2, 0.5), true)
		draw_string(font, p + Vector2(-hw, -float(sp.get_meta("decor_m")) * t - 4), "%.1f m" % sp.get_meta("decor_m"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.8, 0.2))
