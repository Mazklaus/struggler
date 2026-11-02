class_name RoomArt
extends Node2D
## Habillage « Encre et couleur » d'une salle : fond peint en parallaxe, brume, blocs à l'encre,
## halos de lumière. Se greffe sur une Room déjà construite sans rien changer à son gameplay :
## les collisions, ennemis et objets restent ceux de la salle grise.

const CELL := 4.0            # résolution de la carte des blocs (8 cases par tuile)
const MAX_CELLS := 64        # distance maximale mesurée vers l'intérieur des blocs
const MAT_INDEX := {"roche": 0, "bois": 1, "maconnerie": 2, "chair": 3, "eboulis": 4, "fer": 5}

var room: Room
var conf := {}
var dir := ""
var _blocks: ColorRect
var amb_map := PackedStringArray()   # ambiance de chaque case (ligne par ligne), voir ambiance_map
var _amb_w := 0
var _maps_task := -1
var _maps: Array = []
var _on := true
var _saved_solids: Array[Rect2] = []
var _saved_labels: Array = []


func setup(r: Room, zone_dir: String, zone: Dictionary, salle: Dictionary) -> void:
	room = r
	dir = zone_dir
	conf = salle
	name = "RoomArt"
	z_index = -10
	z_as_relative = false
	# Fonds, modules et décors sont réduits à l'écran : mipmaps pour éviter le crénelage.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var ambs: Dictionary = zone.get("ambiances", {})
	var main: Dictionary = ambs.get(salle.get("ambiance", ""), salle)
	var pal: Dictionary = salle.get("palette", main.get("palette", {}))
	_build_fonds(zone, salle, main)

	_blocks = ColorRect.new()
	_blocks.size = room.size
	_blocks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://art/shaders/encre_blocs.gdshader")
	# Les cartes des blocs se calculent sur un autre fil, pendant le fondu d'entrée de salle :
	# la salle grise reste affichée jusqu'à ce qu'elles soient prêtes, sans à-coup.
	var solids := room.solids.duplicate()
	var mats := room.solid_mats.duplicate()
	var sz := room.size
	_maps_task = WorkerThreadPool.add_task(func(): _maps = _block_maps(solids, mats, sz))
	_blocks.visible = false
	mat.set_shader_parameter("room_size", room.size)
	mat.set_shader_parameter("max_dist", MAX_CELLS * CELL)
	for k in MAT_INDEX:
		var path: String = zone.get("matieres", {}).get(k, "")
		if path != "":
			mat.set_shader_parameter("t_" + k, load(dir + path))
	for k in ["encre", "ombre", "lumiere"]:
		if pal.has(k):
			mat.set_shader_parameter("c_" + k, Color(pal[k]))
	_blocks.material = mat
	add_child(_blocks)

	# Objets de décor posés sur le sol (derrière Wendel, ou devant avec « devant »).
	for dc in salle.get("decors", []):
		var sp := Sprite2D.new()
		sp.texture = load(dir + dc.image)
		# Taille réelle en mètres (1 case = 1 m) ; « echelle » reste accepté pour un réglage brut.
		var k: float = float(dc.hauteur) * Room.TILE / sp.texture.get_height() if dc.has("hauteur") else float(dc.get("echelle", 0.5))
		sp.scale = Vector2(k, k)
		if dc.get("miroir", false):
			sp.scale = Vector2(-k, k)
		sp.centered = true
		sp.offset = Vector2(0, -sp.texture.get_height() * 0.5)
		sp.position = Vector2(float(dc.x) * Room.TILE, float(dc.y) * Room.TILE + 4.0)
		sp.z_index = 40 if dc.get("devant", false) else -12
		sp.set_meta("decor_m", float(sp.texture.get_height()) * k / Room.TILE)
		# Teinté par la lumière de la salle, pour qu'il ne paraisse pas collé.
		sp.modulate = Color.WHITE.lerp(Color(pal.get("lumiere", "ffffff")), 0.35)
		add_child(sp)
		if dc.get("lumiere", false):
			_glow(sp.position + Vector2(0, -sp.texture.get_height() * k * 0.3), Color(pal.get("lumiere", "ffaa66")), 1.6)

	# Halos chauds sur les brasiers et cercles de sel.
	for rs in room.rests:
		_glow((rs.rect as Rect2).get_center(), Color(pal.get("lumiere", "ffaa66")), 2.2)
	apply(true)


func _glow(at: Vector2, c: Color, size: float) -> void:
		var glow := Sprite2D.new()
		var g := GradientTexture2D.new()
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		g.width = 256
		g.height = 256
		var grad := Gradient.new()
		grad.set_color(0, Color(c, 0.55))
		grad.set_color(1, Color(c, 0.0))
		g.gradient = grad
		glow.texture = g
		glow.scale = Vector2(size, size)
		glow.position = at
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = add
		glow.z_index = 5
		add_child(glow)


## Montre l'habillage (true) ou rend la salle grise d'origine (false).
func apply(on: bool) -> void:
	_on = on
	visible = on
	var deco := room.deco
	if on and not _blocks.visible:
		return   # cartes pas encore prêtes : les blocs gris restent en attendant
	if on:
		if _saved_solids.is_empty() and not deco.solids.is_empty():
			_saved_solids = deco.solids
			_saved_labels = deco.labels
		deco.solids = [] as Array[Rect2]
		deco.labels = []
	elif not _saved_solids.is_empty():
		deco.solids = _saved_solids
		deco.labels = _saved_labels
	deco.queue_redraw()


func _process(_delta: float) -> void:
	if _maps_task >= 0 and WorkerThreadPool.is_task_completed(_maps_task):
		WorkerThreadPool.wait_for_task_completion(_maps_task)
		_maps_task = -1
		var m := _blocks.material as ShaderMaterial
		m.set_shader_parameter("dist_tex", ImageTexture.create_from_image(_maps[0]))
		m.set_shader_parameter("mat_tex", ImageTexture.create_from_image(_maps[1]))
		_blocks.visible = true
		apply(_on)
	if visible and _blocks.material:
		(_blocks.material as ShaderMaterial).set_shader_parameter("night", World.night_amount())


## Les fonds de la salle, un par ambiance. Une salle sans « regles » ni « zones » n'a qu'une
## ambiance. Sinon chaque case vide reçoit la sienne (voir ambiance_map), et chaque fond n'est
## visible que sur ses cases, avec un fondu de quelques cases aux frontières.
func _build_fonds(zone: Dictionary, salle: Dictionary, main: Dictionary) -> void:
	var ambs: Dictionary = zone.get("ambiances", {})
	if not salle.has("regles") and not salle.has("zones"):
		_add_fond(main, null)
		return
	ambiance_map(salle, salle.get("ambiance", ""))
	var used := {}
	for a in amb_map:
		used[a] = true
	for a in used:
		if not ambs.has(a):
			push_warning("ambiance inconnue : %s (salle %s)" % [a, room.id])
			continue
		_add_fond(ambs[a], _mask_for(a, int(salle.get("fondu_cases", 3))))


func _add_fond(amb: Dictionary, mask: Texture2D) -> void:
	var fc := FondCalque.new()
	add_child(fc)
	fc.setup(room, dir, amb, mask)


## Ambiance de chaque case, d'après la forme de la salle : une case regarde ce qu'elle a
## au-dessus d'elle. Rien (hors bordure du haut) : « ciel ». Sinon la lettre du premier bloc
## rencontré (« t » terril, « b » ou « - » boisage, « M » maçonnerie…) ou « * » pour tout bloc.
## Les « zones » (rectangles en cases, de [x, y] à [x, y] exclus) passent par-dessus.
func ambiance_map(salle: Dictionary, defaut: String) -> PackedStringArray:
	var rows: Array = Rooms.DATA[room.id].rows
	var w: int = rows[0].length()
	var h: int = rows.size()
	_amb_w = w
	var regles: Dictionary = salle.get("regles", {})
	# Bordure du haut : les premières lignes presque pleines (le plafond de la salle).
	var top := 0
	while top < h and float((rows[top] as String).count(" ")) < w * 0.1 and top < 3:
		top += 1
	amb_map.resize(w * h)
	for x in w:
		var cover := ""
		for y in h:
			var ch: String = (rows[y] as String)[x]
			var solid := ch in "#XwbMota-"   # blocs et bois (voir la légende de rooms.gd)
			if y >= top and solid:
				cover = ch
			var a := defaut
			if not regles.is_empty():
				if cover == "":
					a = regles.get("ciel", defaut)
				else:
					a = regles.get(cover, regles.get("*", defaut))
			amb_map[y * w + x] = a
	for z in salle.get("zones", []):
		for y in range(int(z.de[1]), int(z.a[1])):
			for x in range(int(z.de[0]), int(z.a[0])):
				if x >= 0 and x < w and y >= 0 and y < h:
					amb_map[y * w + x] = z.ambiance
	return amb_map


func ambiance_at(cell: Vector2i) -> String:
	if _amb_w == 0:
		return ""
	return amb_map[cell.y * _amb_w + cell.x]


## Masque d'une ambiance : une case par pixel, adouci sur « fondu » cases (flou en boîte).
func _mask_for(a: String, fondu: int) -> Texture2D:
	var w := _amb_w
	var h := amb_map.size() / w
	var v := PackedFloat32Array()
	v.resize(w * h)
	for i in v.size():
		v[i] = 1.0 if amb_map[i] == a else 0.0
	var r := maxi(fondu / 2, 0)
	for pass_ in 2:
		var o := PackedFloat32Array()
		o.resize(w * h)
		for y in h:
			for x in w:
				var s := 0.0
				var n := 0
				for d in range(-r, r + 1):
					var xx := x + d if pass_ == 0 else x
					var yy := y if pass_ == 0 else y + d
					if xx >= 0 and xx < w and yy >= 0 and yy < h:
						s += v[yy * w + xx]
						n += 1
				o[y * w + x] = s / float(n)
		v = o
	var img := Image.create(w, h, false, Image.FORMAT_L8)
	for y in h:
		for x in w:
			img.set_pixel(x, y, Color(v[y * w + x], 0, 0))
	return ImageTexture.create_from_image(img)


## Deux cartes de la salle à 8 px la case : distance de chaque case pleine à l'air le plus proche
## (pour l'ombre, les hachures et le contour), et matière de chaque case.
func _block_maps(solids: Array, mats: Array, sz: Vector2) -> Array:
	var gw := int(ceil(sz.x / CELL))
	var gh := int(ceil(sz.y / CELL))
	var mat := PackedByteArray()
	mat.resize(gw * gh)
	mat.fill(0)
	for i in solids.size():
		var r: Rect2 = solids[i]
		var m: int = MAT_INDEX.get(mats[i] if i < mats.size() else "roche", 0)
		for y in range(int(r.position.y / CELL), int(r.end.y / CELL)):
			for x in range(int(r.position.x / CELL), int(r.end.x / CELL)):
				if x >= 0 and y >= 0 and x < gw and y < gh:
					mat[y * gw + x] = (m + 1) * 32
	# Distance de chanfrein en deux passes (le bord de la salle compte comme de la roche).
	var big := MAX_CELLS * 3
	var dist := PackedInt32Array()
	dist.resize(gw * gh)
	for i in gw * gh:
		dist[i] = big if mat[i] > 0 else 0
	for y in gh:
		for x in gw:
			var i := y * gw + x
			if dist[i] == 0:
				continue
			var v := dist[i]
			if x > 0: v = mini(v, dist[i - 1] + 3)
			if y > 0:
				v = mini(v, dist[i - gw] + 3)
				if x > 0: v = mini(v, dist[i - gw - 1] + 4)
				if x < gw - 1: v = mini(v, dist[i - gw + 1] + 4)
			dist[i] = v
	for y in range(gh - 1, -1, -1):
		for x in range(gw - 1, -1, -1):
			var i := y * gw + x
			if dist[i] == 0:
				continue
			var v := dist[i]
			if x < gw - 1: v = mini(v, dist[i + 1] + 3)
			if y < gh - 1:
				v = mini(v, dist[i + gw] + 3)
				if x < gw - 1: v = mini(v, dist[i + gw + 1] + 4)
				if x > 0: v = mini(v, dist[i + gw - 1] + 4)
			dist[i] = v
	var dbytes := PackedByteArray()
	dbytes.resize(gw * gh)
	for i in gw * gh:
		dbytes[i] = clampi(int(dist[i] / 3.0 / MAX_CELLS * 255.0), 0, 255)
	var dimg := Image.create_from_data(gw, gh, false, Image.FORMAT_L8, dbytes)
	var mimg := Image.create_from_data(gw, gh, false, Image.FORMAT_L8, mat)
	return [dimg, mimg]
