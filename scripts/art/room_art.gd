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
var _bg: Sprite2D
var _mods: Node2D            # fond en modules répétés (voir _build_modules)
var _mod_len := 0.0
var _blocks: ColorRect
var _haze: ColorRect
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
	var pal: Dictionary = salle.get("palette", {})

	if salle.has("fond"):
		_bg = Sprite2D.new()
		_bg.texture = load(dir + salle.fond)
		_bg.centered = false
		_bg.region_enabled = true
		_bg.z_index = -30
		add_child(_bg)

	if salle.has("fond_modules"):
		_build_modules(salle.fond_modules)

	_haze = ColorRect.new()
	_haze.size = room.size
	_haze.color = Color(pal.get("brume", "000000"))
	_haze.color.a = salle.get("voile", 0.3)
	_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_haze.z_index = -20
	add_child(_haze)

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
		var k: float = dc.get("echelle", 0.5)
		sp.scale = Vector2(k, k)
		if dc.get("miroir", false):
			sp.scale = Vector2(-k, k)
		sp.centered = true
		sp.offset = Vector2(0, -sp.texture.get_height() * 0.5)
		sp.position = Vector2(float(dc.x) * Room.TILE, float(dc.y) * Room.TILE + 4.0)
		sp.z_index = 40 if dc.get("devant", false) else -12
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


## Fond fait de modules : un morceau de décor à la bonne échelle, qui se raccorde à lui-même
## dans l'axe de la salle (vertical pour un puits, horizontal pour une galerie). Plusieurs variantes
## se succèdent dans un ordre fixe mais sans motif visible ; « haut » et « bas » (ou « debut » et
## « fin ») ferment la pile. La taille d'un module est fixée en pixels du monde : c'est elle qui
## règle l'échelle du fond par rapport à Wendel, quelle que soit la taille de la salle.
func _build_modules(m: Dictionary) -> void:
	_mods = Node2D.new()
	_mods.z_index = -30
	add_child(_mods)
	var vertical: bool = m.get("axe", "vertical") == "vertical"
	var base: Array = m.get("base", [])
	if base.is_empty():
		return
	var texs: Array[Texture2D] = []
	for b in base:
		texs.append(load(dir + b))
	var cross: float = m.get("largeur", 1280.0)        # largeur couverte (hauteur si horizontal)
	var side: float = m.get("taille", cross)            # taille d'un module en travers
	var f: float = conf.get("parallaxe", 0.15)
	var length := (room.size.y if vertical else room.size.x) * f + (720.0 if vertical else 1280.0) * 1.5
	# Entre deux modules voisins, le suivant chevauche le précédent et s'y fond (dans les deux sens).
	var fondu: float = m.get("fondu", 0.15) if texs.size() > 1 else 0.0
	var shader: Shader = load("res://art/shaders/fondu_module.gdshader")
	# Grille de colonnes : chaque colonne déroule les variantes dans un ordre décalé et commence
	# plus ou moins haut, pour que la même image ne se retrouve pas côte à côte.
	var cols := int(ceil(cross / (side * (1.0 - fondu)))) if m.has("taille") else 1
	for c in cols:
		var pos := -side * 2.0 * fmod(c * 0.37, 1.0) if c > 0 else 0.0
		var i := c * 2 + 1 if c > 0 else 0
		var first_row := true
		while pos < length:
			var t: Texture2D = texs[(i * 7 + (i / texs.size()) * 3) % texs.size()]
			i += 1
			var sp := Sprite2D.new()
			sp.texture = t
			sp.centered = false
			var k := side / (t.get_width() if vertical else t.get_height())
			sp.scale = Vector2(k, k)
			var step := t.get_height() * k if vertical else t.get_width() * k
			var cross_pos := c * side * (1.0 - fondu)
			if not first_row:
				pos -= step * fondu
			var mat := ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("fondu", 0.0 if first_row else fondu * 1.0)
			mat.set_shader_parameter("fondu_x", 0.0 if c == 0 else fondu)
			mat.set_shader_parameter("vertical", vertical)
			sp.material = mat
			sp.position = Vector2(cross_pos, pos) if vertical else Vector2(pos, cross_pos)
			_mods.add_child(sp)
			pos += step
			first_row = false
		_mod_len = maxf(_mod_len, pos)


func _process(_delta: float) -> void:
	if _maps_task >= 0 and WorkerThreadPool.is_task_completed(_maps_task):
		WorkerThreadPool.wait_for_task_completion(_maps_task)
		_maps_task = -1
		var m := _blocks.material as ShaderMaterial
		m.set_shader_parameter("dist_tex", ImageTexture.create_from_image(_maps[0]))
		m.set_shader_parameter("mat_tex", ImageTexture.create_from_image(_maps[1]))
		_blocks.visible = true
		apply(_on)
	if not visible or (_bg == null and _mods == null):
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var view := get_viewport_rect().size / cam.zoom
	var tl := cam.get_screen_center_position() - view * 0.5
	var f: float = conf.get("parallaxe", 0.15)
	# Le fond couvre la vue et défile au moins d'une fraction f du déplacement de la caméra.
	# S'il est plus grand que nécessaire (image verticale dans une salle étroite), il défile
	# juste assez pour qu'on en voie le haut en haut de la salle et le bas en bas.
	var travel := (room.size - view).max(Vector2.ZERO)
	if _mods:
		# Les modules défilent à la fraction f de la caméra ; centrés dans l'autre axe.
		var fm: float = conf.get("parallaxe", 0.15)
		var vertical: bool = conf.fond_modules.get("axe", "vertical") == "vertical"
		var cross: float = conf.fond_modules.get("largeur", 1280.0)
		var c := cam.get_screen_center_position()
		if vertical:
			_mods.position = Vector2(c.x - cross * 0.5, tl.y * (1.0 - fm))
		else:
			_mods.position = Vector2(tl.x * (1.0 - fm), c.y - cross * 0.5)
		_mods.modulate = Color(1, 1, 1).lerp(Color(0.55, 0.6, 0.8), World.night_amount())
	if _bg == null:
		if _blocks.material:
			(_blocks.material as ShaderMaterial).set_shader_parameter("night", World.night_amount())
		return
	var need := view + travel * f
	var tex := _bg.texture.get_size()
	var k := maxf(need.y / tex.y, need.x / tex.x)
	var shown := tex * k
	var fx := clampf((shown.x - view.x) / travel.x, 0.0, 1.0) if travel.x > 0.0 else 0.0
	var fy := clampf((shown.y - view.y) / travel.y, 0.0, 1.0) if travel.y > 0.0 else 0.0
	_bg.scale = Vector2(k, k)
	_bg.region_rect = Rect2(Vector2.ZERO, tex)
	_bg.position = tl - Vector2(tl.x * fx, tl.y * fy)
	var night := World.night_amount()
	_bg.modulate = Color(1, 1, 1).lerp(Color(0.55, 0.6, 0.8), night)
	if _blocks.material:
		(_blocks.material as ShaderMaterial).set_shader_parameter("night", night)


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
